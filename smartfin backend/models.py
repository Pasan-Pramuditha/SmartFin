from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from database import Base
import datetime

# 1. Users Table (With Social Login and Forgot Password)
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String, index=True)
    last_name = Column(String, index=True)
    email = Column(String, unique=True, index=True)

    password_hash = Column(String, nullable=True)

    reset_password_token = Column(String, nullable=True, index=True)
    reset_password_expires_at = Column(DateTime, nullable=True)

    auth_provider = Column(String, default="local")
    provider_id = Column(String, nullable=True, unique=True)
    profile_picture = Column(String, nullable=True)
    two_factor_enabled = Column(Boolean, default=False)

    created_at = Column(DateTime, default=lambda: datetime.datetime.now(datetime.UTC))

    # Relationships with other tables
    categories = relationship("Category", back_populates="owner")
    transactions = relationship("Transaction", back_populates="owner")
    budgets = relationship("Budget", back_populates="owner")
    insights = relationship("AIInsight", back_populates="owner")
    refresh_tokens = relationship("RefreshToken", back_populates="owner")


# 2. Categories Table (Expense/Income types)
class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True) # Null for predefined global, else user specific
    name = Column(String, index=True) # e.g., Food, Rent, Salary
    category_type = Column(String)    # "income" or "expense"
    icon_name = Column(String, nullable=True)

    # Relationships
    owner = relationship("User", back_populates="categories")
    transactions = relationship("Transaction", back_populates="category")
    budgets = relationship("Budget", back_populates="category")


# 3. Transactions Table
class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))         # User ID
    category_id = Column(Integer, ForeignKey("categories.id")) # Category ID
    amount = Column(Float)
    description = Column(String) # e.g., "KFC Lunch"
    date = Column(DateTime, default=lambda: datetime.datetime.now(datetime.UTC))
    payment_method = Column(String, nullable=True) # Cash, Card
    notes = Column(String, nullable=True)
    receipt_image_url = Column(String, nullable=True) # Receipt image

    # Relationships
    owner = relationship("User", back_populates="transactions")
    category = relationship("Category", back_populates="transactions")


# 4. Budgets Table (Budget limits)
class Budget(Base):
    __tablename__ = "budgets"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    category_id = Column(Integer, ForeignKey("categories.id"))
    monthly_limit = Column(Float) # Monthly maximum limit (e.g., 15000.00)
    month_year = Column(String)   # e.g., "2026-02"

    # Relationships
    owner = relationship("User", back_populates="budgets")
    category = relationship("Category", back_populates="budgets")


# 5. AI Insights Table (Artificial Intelligence reports)
class AIInsight(Base):
    __tablename__ = "ai_insights"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    insight_type = Column(String) # "Prediction", "Anomaly", "Suggestion"
    message = Column(String)      # e.g., "Your travel expenses have reduced by 10%"
    generated_date = Column(DateTime, default=lambda: datetime.datetime.now(datetime.UTC))
    is_read = Column(Boolean, default=False) # Check if user has read this

    # Relationships
    owner = relationship("User", back_populates="insights")


# 6. Refresh Tokens Table
class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token = Column(String, unique=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    expires_at = Column(DateTime)
    is_revoked = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.datetime.now(datetime.UTC))

    # Relationships
    owner = relationship("User", back_populates="refresh_tokens")


# 7. Email OTP Table (For Two-Factor Authentication)
class EmailOTP(Base):
    __tablename__ = "email_otps"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True) # Max 1 OTP per user
    otp_code = Column(String(6))
    expires_at = Column(DateTime)
    failed_attempts = Column(Integer, default=0)

    # Relationships
    owner = relationship("User")