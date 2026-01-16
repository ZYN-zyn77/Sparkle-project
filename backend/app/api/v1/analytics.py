from typing import Any, Dict, Optional
from datetime import date, datetime, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func, Integer
from pydantic import BaseModel
import os
import uuid

from app.api.deps import get_db, get_current_user
from app.models.user import User
from app.models.learning_assets import (
    AssetSuggestionLog,
    LearningAsset,
    AssetStatus,
    SuggestionDecision,
    UserSuggestionResponse,
)
from app.services.analytics.weekly_synthesis_service import WeeklySynthesisService
from app.services.llm_service import llm_service

router = APIRouter()


# ============ Suggestion Metrics ============

class SuggestionMetricsResponse(BaseModel):
    """Response schema for suggestion metrics"""
    start_date: date
    end_date: date
    user_id: Optional[str] = None

    # Suggestion evaluation metrics
    trigger_count: int  # Total suggestion evaluations
    suggested_count: int  # Times suggestion was shown
    skip_count: int  # Skipped (conditions not met)
    not_suggested_count: int  # Suppressed (cooldown, etc.)

    # User response metrics
    accept_count: int  # User accepted suggestion
    dismiss_count: int  # User dismissed suggestion
    pending_count: int  # Awaiting response

    # Asset creation metrics
    asset_create_count: int  # Assets created in period
    inbox_activate_count: int  # Assets activated from inbox

    # Derived metrics
    suggestion_rate: float  # suggested_count / trigger_count
    accept_rate: float  # accept_count / suggested_count (click-through)
    activation_rate: float  # inbox_activate_count / asset_create_count


@router.get("/suggestion-metrics", response_model=SuggestionMetricsResponse)
async def get_suggestion_metrics(
    start_date: date = Query(..., description="Start date (inclusive)"),
    end_date: date = Query(..., description="End date (inclusive)"),
    user_id: Optional[UUID] = Query(None, description="Filter by user ID (admin only, or self)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Get suggestion system metrics for analytics dashboard.

    Returns counts of:
    - Suggestion triggers and decisions
    - User responses (accept/dismiss/ignore)
    - Asset creation and activation

    **Security**: Non-admin users can only query their own metrics.
    """
    # Security: non-admins can only see their own data
    target_user_id = user_id
    if not current_user.is_admin:
        if user_id and user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Cannot view other users' metrics")
        target_user_id = current_user.id

    # Convert dates to datetime for query
    start_dt = datetime.combine(start_date, datetime.min.time()).replace(tzinfo=timezone.utc)
    end_dt = datetime.combine(end_date, datetime.max.time()).replace(tzinfo=timezone.utc)

    # Build base filter conditions
    log_conditions = [
        AssetSuggestionLog.created_at >= start_dt,
        AssetSuggestionLog.created_at <= end_dt,
    ]
    asset_conditions = [
        LearningAsset.created_at >= start_dt,
        LearningAsset.created_at <= end_dt,
        LearningAsset.deleted_at.is_(None),  # Exclude soft-deleted
    ]

    if target_user_id:
        log_conditions.append(AssetSuggestionLog.user_id == target_user_id)
        asset_conditions.append(LearningAsset.user_id == target_user_id)

    # Query 1: Suggestion log metrics
    log_query = select(
        func.count().label('trigger_count'),
        func.sum(
            func.cast(AssetSuggestionLog.decision == SuggestionDecision.SUGGESTED.value, Integer)
        ).label('suggested_count'),
        func.sum(
            func.cast(AssetSuggestionLog.decision == SuggestionDecision.SKIPPED.value, Integer)
        ).label('skip_count'),
        func.sum(
            func.cast(AssetSuggestionLog.decision == SuggestionDecision.NOT_SUGGESTED.value, Integer)
        ).label('not_suggested_count'),
        func.sum(
            func.cast(AssetSuggestionLog.user_response == UserSuggestionResponse.ACCEPT.value, Integer)
        ).label('accept_count'),
        func.sum(
            func.cast(AssetSuggestionLog.user_response == UserSuggestionResponse.DISMISS.value, Integer)
        ).label('dismiss_count'),
        func.sum(
            func.cast(AssetSuggestionLog.user_response == UserSuggestionResponse.PENDING.value, Integer)
        ).label('pending_count'),
    ).where(and_(*log_conditions))

    log_result = await db.execute(log_query)
    log_row = log_result.first()

    # Query 2: Asset creation count
    asset_create_query = select(
        func.count().label('asset_create_count')
    ).where(and_(*asset_conditions))

    asset_result = await db.execute(asset_create_query)
    asset_row = asset_result.first()

    # Query 3: Inbox activation count (assets that transitioned to ACTIVE)
    # We look at assets currently in ACTIVE status that were updated in the period
    activate_conditions = asset_conditions + [
        LearningAsset.status == AssetStatus.ACTIVE.value,
        LearningAsset.updated_at >= start_dt,
        LearningAsset.updated_at <= end_dt,
    ]
    activate_query = select(
        func.count().label('inbox_activate_count')
    ).where(and_(*activate_conditions))

    activate_result = await db.execute(activate_query)
    activate_row = activate_result.first()

    # Extract values with defaults
    trigger_count = log_row.trigger_count or 0
    suggested_count = log_row.suggested_count or 0
    skip_count = log_row.skip_count or 0
    not_suggested_count = log_row.not_suggested_count or 0
    accept_count = log_row.accept_count or 0
    dismiss_count = log_row.dismiss_count or 0
    pending_count = log_row.pending_count or 0
    asset_create_count = asset_row.asset_create_count or 0
    inbox_activate_count = activate_row.inbox_activate_count or 0

    # Calculate rates (avoid division by zero)
    suggestion_rate = (suggested_count / trigger_count) if trigger_count > 0 else 0.0
    accept_rate = (accept_count / suggested_count) if suggested_count > 0 else 0.0
    activation_rate = (inbox_activate_count / asset_create_count) if asset_create_count > 0 else 0.0

    return SuggestionMetricsResponse(
        start_date=start_date,
        end_date=end_date,
        user_id=str(target_user_id) if target_user_id else None,
        trigger_count=trigger_count,
        suggested_count=suggested_count,
        skip_count=skip_count,
        not_suggested_count=not_suggested_count,
        accept_count=accept_count,
        dismiss_count=dismiss_count,
        pending_count=pending_count,
        asset_create_count=asset_create_count,
        inbox_activate_count=inbox_activate_count,
        suggestion_rate=round(suggestion_rate, 4),
        accept_rate=round(accept_rate, 4),
        activation_rate=round(activation_rate, 4),
    )


# ============ Weekly Reports ============

@router.post("/reports/generate", response_model=Dict[str, Any])
async def generate_weekly_report(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Trigger on-demand generation of the weekly learning report.
    Returns the JSON data immediately and schedules PDF generation.
    """
    # Initialize service
    service = WeeklySynthesisService(db, llm_service)

    try:
        report_data = await service.generate_report(str(current_user.id))
        
        # Generate PDF filename
        filename = f"weekly_report_{current_user.id}_{report_data['week_of']}.pdf"
        output_path = os.path.join("/tmp", filename) # Temp location for MVP
        
        # Schedule PDF generation
        background_tasks.add_task(service.generate_pdf, report_data, output_path)
        
        return {
            "message": "Report generation started",
            "data": report_data,
            "download_url": f"/api/v1/analytics/reports/download/{filename}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reports/download/{filename}")
async def download_report(
    filename: str,
    current_user: User = Depends(get_current_user)
):
    """
    Download a generated PDF report.
    """
    # Security check: filename should contain user_id to prevent accessing others' reports
    if str(current_user.id) not in filename:
        raise HTTPException(status_code=403, detail="Access denied")
        
    file_path = os.path.join("/tmp", filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Report not found")
        
    return FileResponse(file_path, media_type="application/pdf", filename=filename)
