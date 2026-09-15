from pydantic import BaseModel
from typing import Optional
from datetime import datetime

# --- User Schemas ---
class UserCreate(BaseModel):
    first_name: str
    last_name: str
    email: str
    password: Optional[str] = None
    auth_provider: str = "local"
    provider_id: Optional[str] = None
    profile_picture: Optional[str] = None
    two_factor_enabled: Optional[bool] = False

class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    profile_picture: Optional[str] = None
    otp_code: Optional[str] = None

class PasswordChangeRequest(BaseModel):
    old_password: str
    new_password: str
    otp_code: Optional[str] = None

class TwoFactorToggleRequest(BaseModel):
    enable: bool
    otp_code: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    email: str
    auth_provider: str
    created_at: datetime
    profile_picture: Optional[str] = None
    two_factor_enabled: bool

    class Config:
        from_attributes = True

class UserLogin(BaseModel):
    email: str
    password: str
    is_biometric: Optional[bool] = False

class Token(BaseModel):
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    token_type: Optional[str] = None
    user_id: Optional[int] = None
    user_name: Optional[str] = None
    requires_2fa: Optional[bool] = False
    temp_token: Optional[str] = None

class VerifyEmailOTPRequest(BaseModel):
    temp_token: str
    otp_code: str

class ResendOTPRequest(BaseModel):
    temp_token: str

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class LogoutRequest(BaseModel):
    refresh_token: str

class SocialLogin(BaseModel):
    token: str


class ForgotPasswordRequest(BaseModel):
    email: str


class EmailCheckRequest(BaseModel):
    email: str


class ForgotPasswordConfirm(BaseModel):
    email: str
    reset_code: str
    new_password: str

# --- Category Schemas ---
class CategoryBase(BaseModel):
    name: str 
    category_type: str 
    icon_name: Optional[str] = None
    user_id: Optional[int] = None

class CategoryCreate(CategoryBase):
    pass

class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    category_type: Optional[str] = None
    icon_name: Optional[str] = None

class CategoryResponse(CategoryBase):
    id: int

    class Config:
        from_attributes = True

# --- Transaction Schemas ---
class TransactionBase(BaseModel):
    category_id: int
    amount: float
    description: str
    date: datetime
    payment_method: Optional[str] = None
    notes: Optional[str] = None
    receipt_image_url: Optional[str] = None

class TransactionCreate(TransactionBase):
    pass

class TransactionUpdate(BaseModel):
    category_id: Optional[int] = None
    amount: Optional[float] = None
    description: Optional[str] = None
    date: Optional[datetime] = None
    payment_method: Optional[str] = None
    notes: Optional[str] = None
    receipt_image_url: Optional[str] = None

class TransactionResponse(TransactionBase):
    id: int
    user_id: int

    class Config:
        from_attributes = True

class TransactionTitleRequest(BaseModel):
    title: str
    type: str = "expense" # income or expense


# --- Budget Schemas ---
class BudgetBase(BaseModel):
    category_id: int
    monthly_limit: float
    month_year: str

class BudgetCreate(BudgetBase):
    pass

class BudgetUpdate(BaseModel):
    category_id: Optional[int] = None
    monthly_limit: Optional[float] = None
    month_year: Optional[str] = None

class BudgetResponse(BudgetBase):
    id: int
    user_id: int

    class Config:
        from_attributes = True

# --- AI Insight Schemas ---
class AIInsightBase(BaseModel):
    insight_type: str
    message: str
    is_read: bool = False

class AIInsightCreate(AIInsightBase):
    pass

class AIInsightUpdate(BaseModel):
    is_read: Optional[bool] = None

class AIInsightResponse(AIInsightBase):
    id: int
    user_id: int
    generated_date: datetime

    class Config:
        from_attributes = True