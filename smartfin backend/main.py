from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Request, BackgroundTasks
from fastapi.staticfiles import StaticFiles
import os
import shutil
import urllib.request
import json
from sqlalchemy.orm import Session
import database
import models
import schemas
import bcrypt
import jwt
from datetime import datetime, timedelta
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
import re
import pandas as pd
import pickle
import random
from dotenv import load_dotenv

load_dotenv()

# Connecting to the Database (Creating Tables)
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="SmartFin API")

# --- Setup for Image Uploads ---
UPLOAD_DIR = "uploads/profile_pictures"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# --- Global NLP Model Setup ---
global_vectorizer = None
global_model = None
is_global_model_trained = False


@app.on_event("startup")
def load_global_nlp_model():
    global is_global_model_trained, global_vectorizer, global_model
    try:
        # Load the pre-trained models from the pickle files
        with open("category_model.pkl", "rb") as f:
            global_model = pickle.load(f)

        with open("vectorizer.pkl", "rb") as f:
            global_vectorizer = pickle.load(f)

        is_global_model_trained = True
        print("Global NLP Model loaded successfully from the local files on startup.")
    except Exception as e:
        print(f"Failed to load global NLP model. Make sure to run 'python train_model.py' first. Error: {e}")


# --- Secrets and settings required for JWT Token ---
SECRET_KEY = "smartfin_super_secret_key_123"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def read_root():
    return {"message": "Welcome to SmartFin API! Database Connected Successfully."}


# Hashing the Password
def get_password_hash(password: str):
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed_password = bcrypt.hashpw(pwd_bytes, salt)
    return hashed_password.decode('utf-8')


# Checking if the given Password matches the Hash in the Database
def verify_password(plain_password: str, hashed_password: str):
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))


# Creating the Access Token (short-lived: 15 min)
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


# Creating the Refresh Token (long-lived: 7 days)
def create_refresh_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


# Temporary 2FA Token (short-lived: 5 min)
def create_temp_2fa_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=5)
    to_encode.update({"exp": expire, "type": "temp_2fa"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def send_email_otp(email: str, code: str):
    import smtplib
    from email.message import EmailMessage
    import os

    print("\\n" + "=" * 50)
    print(f"📧 Sending OPT to {email}")
    print(f"🔑 Your SmartFin login code is: {code}")
    print("=" * 50 + "\\n")

    sender_email = os.environ.get("SMTP_EMAIL", "")
    sender_password = os.environ.get("SMTP_PASSWORD", "")

    if not sender_email or not sender_password:
        print("⚠️ SMTP_EMAIL or SMTP_PASSWORD not set in environment.")
        print("⚠️ To send real emails, set these environment variables (e.g. for Gmail App Passwords).")
        return

    try:
        msg = EmailMessage()
        msg.set_content(
            f"Hello,\n\nYour SmartFin verification code is: {code}\n\nThis code will expire in 5 minutes.\nDo not share this code with anyone.\n\nThank you,\nSmartFin Team")
        msg["Subject"] = "SmartFin Verification Code"
        msg["From"] = sender_email
        msg["To"] = email

        server = smtplib.SMTP("smtp.gmail.com", 587)
        server.starttls()
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        print(f"✅ OTP email successfully sent to {email}")
    except Exception as e:
        print(f"❌ Failed to send email: {e}")


def send_password_reset_email(email: str, code: str):
    import smtplib
    from email.message import EmailMessage
    import os

    print("\\n" + "=" * 50)
    print(f"📧 Sending password reset code to {email}")
    print(f"🔑 Your SmartFin password reset code is: {code}")
    print("=" * 50 + "\\n")

    sender_email = os.environ.get("SMTP_EMAIL", "")
    sender_password = os.environ.get("SMTP_PASSWORD", "")

    if not sender_email or not sender_password:
        print("⚠️ SMTP_EMAIL or SMTP_PASSWORD not set in environment.")
        print("⚠️ To send real emails, set these environment variables (e.g. for Gmail App Passwords).")
        return

    try:
        msg = EmailMessage()
        msg.set_content(
            f"Hello,\n\nYour SmartFin password reset code is: {code}\n\nThis code will expire in 10 minutes.\nIf you did not request this, ignore this email.\n\nThank you,\nSmartFin Team")
        msg["Subject"] = "SmartFin Password Reset Code"
        msg["From"] = sender_email
        msg["To"] = email

        server = smtplib.SMTP("smtp.gmail.com", 587)
        server.starttls()
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        print(f"✅ Password reset email successfully sent to {email}")
    except Exception as e:
        print(f"❌ Failed to send password reset email: {e}")


# Dependency: Extract and verify Bearer token from Authorization header
def get_current_user(request: Request, db: Session = Depends(get_db)):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    token = auth_header.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        email: str = payload.get("sub")
        if not email:
            raise HTTPException(status_code=401, detail="Invalid token")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


# ==========================================
# 1. USERS API
# ==========================================

@app.post("/users/", response_model=schemas.UserResponse)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    email_regex = r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
    if not re.match(email_regex, user.email):
        raise HTTPException(status_code=400, detail="Invalid email format. Please provide a valid email address (e.g., user@gmail.com).")

    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = get_password_hash(user.password) if user.password else None

    new_user = models.User(
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        password_hash=hashed_password,
        auth_provider=user.auth_provider,
        provider_id=user.provider_id,
        profile_picture=user.profile_picture
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


# ==========================================
# 1.5 SOCIAL LOGIN API (Google Auth)
# ==========================================
# Updated to match the frontend (api_service.dart) serverClientId
GOOGLE_CLIENT_ID = "1048975331457-khgpuu3hhqm0jblpof2foph89ents3to.apps.googleusercontent.com"


@app.post("/auth/google", response_model=schemas.Token)
def google_auth(login_data: schemas.SocialLogin, db: Session = Depends(get_db)):
    try:
        # Verify the token with Google
        id_info = id_token.verify_oauth2_token(
            login_data.token, google_requests.Request(), GOOGLE_CLIENT_ID
        )

        email = id_info.get("email")
        if not email:
            raise HTTPException(status_code=400, detail="Email not found in Google Token")

        # Check if user exists
        db_user = db.query(models.User).filter(models.User.email == email).first()

        if not db_user:
            # Create user if not exists
            new_user = models.User(
                first_name=id_info.get("given_name", ""),
                last_name=id_info.get("family_name", ""),
                email=email,
                auth_provider="google",
                provider_id=id_info.get("sub"),
                profile_picture=id_info.get("picture")
            )
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            db_user = new_user
        else:
            # Update profile picture on subsequent logins
            picture_url = id_info.get("picture")
            if picture_url and db_user.profile_picture != picture_url:
                db_user.profile_picture = picture_url
                db.commit()
                db.refresh(db_user)

        # Create access + refresh tokens
        access_token = create_access_token(data={"sub": db_user.email})
        refresh_token = create_refresh_token(data={"sub": db_user.email})

        # Save refresh token to DB
        db_refresh = models.RefreshToken(
            token=refresh_token,
            user_id=db_user.id,
            expires_at=datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        )
        db.add(db_refresh)
        db.commit()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user_id": db_user.id,
            "user_name": f"{db_user.first_name} {db_user.last_name}"
        }

    except ValueError as e:
        print(f"Google Token validation failed: {e}")
        raise HTTPException(status_code=400, detail="Invalid Google token")

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Here's the real problem: {str(e)}")


@app.post("/auth/facebook", response_model=schemas.Token)
def facebook_auth(login_data: schemas.SocialLogin, db: Session = Depends(get_db)):
    try:
        # Verify token with Facebook
        url = f"https://graph.facebook.com/me?fields=id,first_name,last_name,email,picture&access_token={login_data.token}"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            fb_data = json.loads(response.read().decode())

        email = fb_data.get("email")
        if not email:
            raise HTTPException(status_code=400, detail="Email not provided by Facebook")

        db_user = db.query(models.User).filter(models.User.email == email).first()

        if not db_user:
            picture_url = None
            if "picture" in fb_data and "data" in fb_data["picture"]:
                picture_url = fb_data["picture"]["data"].get("url")

            new_user = models.User(
                first_name=fb_data.get("first_name", ""),
                last_name=fb_data.get("last_name", ""),
                email=email,
                auth_provider="facebook",
                provider_id=fb_data.get("id"),
                profile_picture=picture_url
            )
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            db_user = new_user
        else:
            # Update profile picture on subsequent logins
            picture_url = None
            if "picture" in fb_data and "data" in fb_data["picture"]:
                picture_url = fb_data["picture"]["data"].get("url")

            if picture_url and db_user.profile_picture != picture_url:
                db_user.profile_picture = picture_url
                db.commit()
                db.refresh(db_user)

        access_token = create_access_token(
            data={"sub": db_user.email}
        )
        refresh_token = create_refresh_token(data={"sub": db_user.email})  # Added refresh token for Facebook

        # Save refresh token to DB
        db_refresh = models.RefreshToken(
            token=refresh_token,
            user_id=db_user.id,
            expires_at=datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        )
        db.add(db_refresh)
        db.commit()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,  # Added refresh token for Facebook
            "token_type": "bearer",
            "user_id": db_user.id,
            "user_name": f"{db_user.first_name} {db_user.last_name}"
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Facebook login failed: {str(e)}")


@app.post("/login/", response_model=schemas.Token)
def login(user_credentials: schemas.UserLogin, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == user_credentials.email).first()
    if not user:
        raise HTTPException(status_code=403, detail="The email address or password you entered is incorrect!")

    if not user.password_hash or not verify_password(user_credentials.password, user.password_hash):
        raise HTTPException(status_code=403, detail="The email address or password you entered is incorrect!")

    # By-pass 2FA for biometric logins
    if user_credentials.is_biometric:
        access_token = create_access_token(data={"sub": user.email})
        refresh_token = create_refresh_token(data={"sub": user.email})

        db_refresh = models.RefreshToken(
            token=refresh_token,
            user_id=user.id,
            expires_at=datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        )
        db.add(db_refresh)
        db.commit()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user_id": user.id,
            "user_name": user.first_name,
            "requires_2fa": False
        }

    # ALWAYS require 2FA on password login for 'First Day' and 'New Phone' scenarios
    otp_code = f"{random.randint(100000, 999999)}"

    # Overwrite existing OTP
    existing_otp = db.query(models.EmailOTP).filter(models.EmailOTP.user_id == user.id).first()
    if existing_otp:
        db.delete(existing_otp)
        db.commit()

    new_otp = models.EmailOTP(
        user_id=user.id,
        otp_code=otp_code,
        expires_at=datetime.utcnow() + timedelta(minutes=5),
        failed_attempts=0
    )
    db.add(new_otp)
    db.commit()

    background_tasks.add_task(send_email_otp, user.email, otp_code)

    temp_token = create_temp_2fa_token(data={"sub": user.email, "user_id": user.id})
    return {
        "requires_2fa": True,
        "temp_token": temp_token
    }


@app.post("/auth/forgot-password/request")
def request_password_reset(
        body: schemas.ForgotPasswordRequest,
        background_tasks: BackgroundTasks,
        db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.email == body.email).first()

    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email")

    if not user.password_hash:
        raise HTTPException(status_code=400, detail="This account uses social login. Please sign in with Google or Facebook")

    reset_code = f"{random.randint(100000, 999999)}"
    user.reset_password_token = reset_code
    user.reset_password_expires_at = datetime.utcnow() + timedelta(minutes=10)
    db.commit()

    background_tasks.add_task(send_password_reset_email, user.email, reset_code)
    return {"message": "Reset code sent to your email"}


@app.post("/auth/check-email")
def check_email_exists(body: schemas.EmailCheckRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == body.email).first()

    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email")

    if not user.password_hash:
        raise HTTPException(
            status_code=400,
            detail="This account uses social login. Please sign in with Google or Facebook"
        )

    return {"message": "Email exists"}


@app.post("/auth/forgot-password/confirm")
def confirm_password_reset(body: schemas.ForgotPasswordConfirm, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == body.email).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid reset request")

    if not user.password_hash:
        raise HTTPException(status_code=400, detail="Social login users cannot reset password this way")

    if not user.reset_password_token or not user.reset_password_expires_at:
        raise HTTPException(status_code=400, detail="No reset code found. Please request a new code")

    if datetime.utcnow() > user.reset_password_expires_at:
        user.reset_password_token = None
        user.reset_password_expires_at = None
        db.commit()
        raise HTTPException(status_code=400, detail="Reset code has expired. Please request a new code")

    if user.reset_password_token != body.reset_code:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    user.password_hash = get_password_hash(body.new_password)
    user.reset_password_token = None
    user.reset_password_expires_at = None

    # Security: revoke all sessions after password reset.
    db.query(models.RefreshToken).filter(models.RefreshToken.user_id == user.id).delete()

    db.commit()
    return {"message": "Password reset successful"}


# --- Verify 2FA OTP Endpoint ---
@app.post("/login/verify-2fa")
def verify_2fa(body: schemas.VerifyEmailOTPRequest, db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(body.temp_token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "temp_2fa":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user_id = payload.get("user_id")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired session")

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    db_otp = db.query(models.EmailOTP).filter(models.EmailOTP.user_id == user_id).first()
    if not db_otp:
        raise HTTPException(status_code=400, detail="No OTP requested or OTP expired")

    if datetime.utcnow() > db_otp.expires_at:
        db.delete(db_otp)
        db.commit()
        raise HTTPException(status_code=400, detail="OTP has expired. Please resend.")

    if db_otp.otp_code != body.otp_code:
        db_otp.failed_attempts += 1
        if db_otp.failed_attempts >= 3:
            db.delete(db_otp)
            db.commit()
            raise HTTPException(status_code=403, detail="Too many failed attempts. Please login again.")
        db.commit()
        raise HTTPException(status_code=400, detail="Incorrect OTP code")

    # OTP is valid!
    db.delete(db_otp)
    db.commit()

    access_token = create_access_token(data={"sub": user.email})
    refresh_token = create_refresh_token(data={"sub": user.email})

    db_refresh = models.RefreshToken(
        token=refresh_token,
        user_id=user.id,
        expires_at=datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    )
    db.add(db_refresh)
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": user.id,
        "user_name": user.first_name
    }


# --- Resend 2FA OTP Endpoint ---
@app.post("/login/resend-otp")
def resend_otp(body: schemas.ResendOTPRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(body.temp_token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "temp_2fa":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user_id = payload.get("user_id")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired session")

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    otp_code = f"{random.randint(100000, 999999)}"

    existing_otp = db.query(models.EmailOTP).filter(models.EmailOTP.user_id == user.id).first()
    if existing_otp:
        existing_otp.otp_code = otp_code
        existing_otp.expires_at = datetime.utcnow() + timedelta(minutes=5)
        existing_otp.failed_attempts = 0
    else:
        new_otp = models.EmailOTP(
            user_id=user.id,
            otp_code=otp_code,
            expires_at=datetime.utcnow() + timedelta(minutes=5),
            failed_attempts=0
        )
        db.add(new_otp)

    db.commit()
    background_tasks.add_task(send_email_otp, user.email, otp_code)

    return {"message": "OTP resent successfully"}


# --- 2FA Challenge Endpoint for sensitive actions ---
@app.post("/users/me/2fa-challenge")
def request_2fa_challenge(background_tasks: BackgroundTasks, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    otp_code = f"{random.randint(100000, 999999)}"

    existing_otp = db.query(models.EmailOTP).filter(models.EmailOTP.user_id == current_user.id).first()
    if existing_otp:
        existing_otp.otp_code = otp_code
        existing_otp.expires_at = datetime.utcnow() + timedelta(minutes=5)
        existing_otp.failed_attempts = 0
    else:
        new_otp = models.EmailOTP(
            user_id=current_user.id,
            otp_code=otp_code,
            expires_at=datetime.utcnow() + timedelta(minutes=5),
            failed_attempts=0
        )
        db.add(new_otp)

    db.commit()
    background_tasks.add_task(send_email_otp, current_user.email, otp_code)
    return {"message": "Verification code sent to your email"}


# --- Password Change Endpoint ---
@app.put("/users/me/password")
def change_password(request: schemas.PasswordChangeRequest, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    if not current_user.password_hash:
        raise HTTPException(status_code=400, detail="Social login users cannot change password this way")

    if not verify_password(request.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect old password")

    if current_user.two_factor_enabled:
        if not request.otp_code:
            raise HTTPException(status_code=403, detail="2FA_REQUIRED")

        db_otp = db.query(models.EmailOTP).filter(models.EmailOTP.user_id == current_user.id).first()
        if not db_otp or db_otp.otp_code != request.otp_code or datetime.utcnow() > db_otp.expires_at:
            raise HTTPException(status_code=400, detail="Invalid or expired verification code")

        db.delete(db_otp)  # Consume OTP

    current_user.password_hash = get_password_hash(request.new_password)

    # Security: Revoke all other sessions on password change
    db.query(models.RefreshToken).filter(models.RefreshToken.user_id == current_user.id).delete()

    db.commit()
    return {"message": "Password updated successfully"}


# --- Toggle 2FA Endpoint ---
@app.post("/users/{user_id}/2fa/toggle")
def toggle_2fa(user_id: int, request: schemas.TwoFactorToggleRequest, db: Session = Depends(get_db),
               current_user: models.User = Depends(get_current_user)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user or user.id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # If disabling 2FA and it's currently ON, require OTP
    if not request.enable and user.two_factor_enabled:
        if not request.otp_code:
            raise HTTPException(status_code=403, detail="2FA_REQUIRED")

        db_otp = db.query(models.EmailOTP).filter(models.EmailOTP.user_id == user.id).first()
        if not db_otp or db_otp.otp_code != request.otp_code or datetime.utcnow() > db_otp.expires_at:
            raise HTTPException(status_code=400, detail="Invalid or expired verification code")

        db.delete(db_otp)

    user.two_factor_enabled = request.enable
    db.commit()

    status_str = "enabled" if user.two_factor_enabled else "disabled"
    return {"message": f"Two-Factor Authentication has been {status_str}",
            "two_factor_enabled": user.two_factor_enabled}


# --- Refresh Token Endpoint ---
@app.post("/auth/refresh", response_model=schemas.Token)
def refresh_access_token(body: schemas.RefreshTokenRequest, db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(body.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type")
        email: str = payload.get("sub")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Refresh token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # Check if token exists in DB and not revoked
    db_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token == body.refresh_token,
        models.RefreshToken.is_revoked == False
    ).first()
    if not db_token:
        raise HTTPException(status_code=401, detail="Refresh token revoked or not found")

    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    # Issue new access token (refresh token stays the same)
    new_access_token = create_access_token(data={"sub": user.email})

    return {
        "access_token": new_access_token,
        "refresh_token": body.refresh_token,
        "token_type": "bearer",
        "user_id": user.id,
        "user_name": user.first_name
    }


# --- Logout Endpoint (Revoke Refresh Token) ---
@app.post("/auth/logout")
def logout(body: schemas.LogoutRequest, db: Session = Depends(get_db)):
    db_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token == body.refresh_token
    ).first()
    if db_token:
        db_token.is_revoked = True
        db.commit()
    return {"message": "Logged out successfully"}


@app.get("/users/{user_id}", response_model=schemas.UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@app.put("/users/{user_id}", response_model=schemas.UserResponse)
def update_user(user_id: int, user_update: schemas.UserUpdate, db: Session = Depends(get_db),
                current_user: models.User = Depends(get_current_user)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # No OTP required for standard profile updates (name, etc)
    if user_update.first_name is not None:
        user.first_name = user_update.first_name
    if user_update.last_name is not None:
        user.last_name = user_update.last_name
    if user_update.profile_picture is not None:
        user.profile_picture = user_update.profile_picture

    db.commit()
    db.refresh(user)
    return user


@app.delete("/users/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"message": "User deleted successfully"}


@app.put("/users/{user_id}/change-password")
def change_password(user_id: int, request: schemas.PasswordChangeRequest, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Check if user is social login (they don't have a password to change via this method)
    if user.auth_provider != "local":
        raise HTTPException(status_code=400, detail="Social login users cannot change passwords here.")

    # Verify old password
    if not user.password_hash or not verify_password(request.old_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect current password.")

    # Hash and save new password
    user.password_hash = get_password_hash(request.new_password)
    db.commit()

    return {"message": "Password changed successfully."}


@app.post("/users/{user_id}/upload-profile-picture", response_model=schemas.UserResponse)
async def upload_profile_picture(user_id: int, file: UploadFile = File(...), db: Session = Depends(get_db),
                                 current_user: models.User = Depends(get_current_user)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Create unique filename
    file_extension = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    new_filename = f"user_{user_id}_{datetime.utcnow().timestamp()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, new_filename)

    # Save the file
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Create the public URL (assuming host is available or client adds base URL)
    # We will just save the relative path: "/uploads/profile_pictures/filename"
    # The client can prepend 'baseUrl' to it.
    public_url = f"/uploads/profile_pictures/{new_filename}"

    user.profile_picture = public_url
    db.commit()
    db.refresh(user)
    return user


# ==========================================
# 2. CATEGORIES API
# ==========================================

@app.post("/categories/", response_model=schemas.CategoryResponse)
def create_category(category: schemas.CategoryCreate, user_id: int, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    try:
        new_category = models.Category(
            name=category.name,
            category_type=category.category_type,
            icon_name=category.icon_name,
            user_id=user_id
        )
        db.add(new_category)
        db.commit()
        db.refresh(new_category)
        return new_category
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating category: {str(e)}")


@app.get("/categories/user/{user_id}", response_model=list[schemas.CategoryResponse])
def get_categories(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Fetch global categories (user_id is None) and user-specific categories
    return db.query(models.Category).filter(
        (models.Category.user_id == user_id) | (models.Category.user_id == None)
    ).all()


@app.get("/categories/{category_id}", response_model=schemas.CategoryResponse)
def get_category(category_id: int, db: Session = Depends(get_db),
                 current_user: models.User = Depends(get_current_user)):
    category = db.query(models.Category).filter(models.Category.id == category_id).first()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    return category


@app.put("/categories/{category_id}", response_model=schemas.CategoryResponse)
def update_category(category_id: int, category_update: schemas.CategoryUpdate, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    category = db.query(models.Category).filter(models.Category.id == category_id).first()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")

    if category_update.name is not None:
        category.name = category_update.name
    if category_update.category_type is not None:
        category.category_type = category_update.category_type
    if category_update.icon_name is not None:
        category.icon_name = category_update.icon_name

    db.commit()
    db.refresh(category)
    return category


@app.delete("/categories/{category_id}")
def delete_category(category_id: int, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    category = db.query(models.Category).filter(models.Category.id == category_id).first()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    db.delete(category)
    db.commit()
    return {"message": "Category deleted successfully"}


# ==========================================
# 3. TRANSACTIONS API
# ==========================================

@app.post("/transactions/", response_model=schemas.TransactionResponse)
def create_transaction(transaction: schemas.TransactionCreate, user_id: int, db: Session = Depends(get_db),
                       current_user: models.User = Depends(get_current_user)):
    try:
        new_transaction = models.Transaction(
            user_id=user_id,
            category_id=transaction.category_id,
            amount=transaction.amount,
            description=transaction.description,
            date=transaction.date,
            payment_method=transaction.payment_method,
            notes=transaction.notes,
            receipt_image_url=transaction.receipt_image_url
        )
        db.add(new_transaction)
        db.commit()
        db.refresh(new_transaction)
        return new_transaction
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating transaction: {str(e)}")


@app.get("/transactions/{user_id}", response_model=list[schemas.TransactionResponse])
def get_user_transactions(user_id: int, db: Session = Depends(get_db),
                          current_user: models.User = Depends(get_current_user)):
    transactions = db.query(models.Transaction).filter(models.Transaction.user_id == user_id).all()
    return transactions


@app.get("/transactions/detail/{transaction_id}", response_model=schemas.TransactionResponse)
def get_transaction(transaction_id: int, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    transaction = db.query(models.Transaction).filter(models.Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


@app.put("/transactions/{transaction_id}", response_model=schemas.TransactionResponse)
def update_transaction(transaction_id: int, trans_update: schemas.TransactionUpdate, db: Session = Depends(get_db),
                       current_user: models.User = Depends(get_current_user)):
    transaction = db.query(models.Transaction).filter(models.Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    if trans_update.category_id is not None:
        transaction.category_id = trans_update.category_id
    if trans_update.amount is not None:
        transaction.amount = trans_update.amount
    if trans_update.description is not None:
        transaction.description = trans_update.description
    if trans_update.date is not None:
        transaction.date = trans_update.date
    if trans_update.payment_method is not None:
        transaction.payment_method = trans_update.payment_method
    if trans_update.notes is not None:
        transaction.notes = trans_update.notes
    if trans_update.receipt_image_url is not None:
        transaction.receipt_image_url = trans_update.receipt_image_url

    db.commit()
    db.refresh(transaction)
    return transaction


@app.delete("/transactions/{transaction_id}")
def delete_transaction(transaction_id: int, db: Session = Depends(get_db),
                       current_user: models.User = Depends(get_current_user)):
    transaction = db.query(models.Transaction).filter(models.Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    db.delete(transaction)
    db.commit()
    return {"message": "Transaction deleted successfully"}


@app.post("/transactions/suggest-category/{user_id}", response_model=dict)
def suggest_category(user_id: int, request: schemas.TransactionTitleRequest, db: Session = Depends(get_db),
                     current_user: models.User = Depends(get_current_user)):
    """
    Suggestions a category ID based on the transaction title using NLP (TF-IDF + Naive Bayes).
    Falls back to simple keyword rules if no historical data is available.
    """
    if not request.title or not request.title.strip():
        return {"suggested_category_id": None}

    # Clean the input title
    def clean_text(text: str):
        text = text.lower()
        text = re.sub(r'[^a-z\s]', '', text)
        return text.strip()

    title_clean = clean_text(request.title)

    # 1. Fetch available categories for this user matching the type (income/expense)
    category_type = request.type.lower()
    categories = db.query(models.Category).filter(
        (models.Category.user_id == user_id) | (models.Category.user_id == None),
        models.Category.category_type.ilike(category_type)
    ).all()

    # helper for matching global string predictions to User's actual DB categories
    def find_best_category_id(predicted_name: str):
        predicted_clean = predicted_name.lower().strip()
        for cat in categories:
            cat_name_clean = cat.name.lower().strip()
            # Try exact match first
            if predicted_clean == cat_name_clean:
                return cat.id
            # Then try substring matched on word boundaries
            if f" {predicted_clean} " in f" {cat_name_clean} " or f" {cat_name_clean} " in f" {predicted_clean} ":
                return cat.id
        return None

    # 2. Try Global Pre-trained Model
    if is_global_model_trained:
        try:
            X_test_global = global_vectorizer.transform([title_clean])

            # Since vectorizer returns all 0s for unknown words, check if any feature matched
            if X_test_global.nnz > 0:
                prediction_probs = global_model.predict_proba(X_test_global)[0]
                max_prob_index = np.argmax(prediction_probs)
                max_prob = prediction_probs[max_prob_index]
                predicted_category_name = str(global_model.classes_[max_prob_index])

                # If the global model is somewhat confident (prob > 1/12 classes)
                if max_prob > 0.10:
                    # Find matching user category ID based on the string name
                    matched_cat_id = find_best_category_id(predicted_category_name)
                    if matched_cat_id:
                        return {
                            "suggested_category_id": matched_cat_id,
                            "suggested_category_name": predicted_category_name,
                            "message": "Category found."
                        }
                    else:
                        # Category predicted successfully but doesn't exist in user's DB
                        return {
                            "suggested_category_id": None,
                            "suggested_category_name": predicted_category_name.capitalize(),
                            "message": f"Please add '{predicted_category_name.capitalize()}' category to continue."
                        }
        except Exception as e:
            print(f"Global Prediction error: {e}")

    return {
        "suggested_category_id": None,
        "suggested_category_name": None,
        "message": "No category suggested."
    }


# ==========================================
# 4. BUDGETS API
# ==========================================

@app.post("/budgets/", response_model=schemas.BudgetResponse)
def create_budget(budget: schemas.BudgetCreate, user_id: int, db: Session = Depends(get_db),
                  current_user: models.User = Depends(get_current_user)):
    try:
        new_budget = models.Budget(
            user_id=user_id,
            category_id=budget.category_id,
            monthly_limit=budget.monthly_limit,
            month_year=budget.month_year
        )
        db.add(new_budget)
        db.commit()
        db.refresh(new_budget)
        return new_budget
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating budget: {str(e)}")


@app.get("/budgets/user/{user_id}", response_model=list[schemas.BudgetResponse])
def get_user_budgets(user_id: int, db: Session = Depends(get_db),
                     current_user: models.User = Depends(get_current_user)):
    return db.query(models.Budget).filter(models.Budget.user_id == user_id).all()


@app.get("/budgets/{budget_id}", response_model=schemas.BudgetResponse)
def get_budget(budget_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    budget = db.query(models.Budget).filter(models.Budget.id == budget_id).first()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    return budget


@app.put("/budgets/{budget_id}", response_model=schemas.BudgetResponse)
def update_budget(budget_id: int, budget_update: schemas.BudgetUpdate, db: Session = Depends(get_db),
                  current_user: models.User = Depends(get_current_user)):
    budget = db.query(models.Budget).filter(models.Budget.id == budget_id).first()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")

    if budget_update.category_id is not None:
        budget.category_id = budget_update.category_id
    if budget_update.monthly_limit is not None:
        budget.monthly_limit = budget_update.monthly_limit
    if budget_update.month_year is not None:
        budget.month_year = budget_update.month_year

    db.commit()
    db.refresh(budget)
    return budget


@app.delete("/budgets/{budget_id}")
def delete_budget(budget_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    budget = db.query(models.Budget).filter(models.Budget.id == budget_id).first()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    db.delete(budget)
    db.commit()
    return {"message": "Budget deleted successfully"}


@app.get("/budgets/predict/{user_id}", response_model=dict)
def predict_budgets(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    six_months_ago = datetime.utcnow() - timedelta(days=180)

    # Needs to be explicitly filtered by the user AND date
    transactions = db.query(models.Transaction).filter(
        models.Transaction.user_id == user_id,
        models.Transaction.date >= six_months_ago
    ).order_by(models.Transaction.date.asc()).all()

    if not transactions:
        return {}

    # Group by (year, month) and category_id
    cat_monthly_data = {}  # { category_id: { (year, month): total_spent } }
    unique_months = []

    for t in transactions:
        yr_month = (t.date.year, t.date.month)
        if yr_month not in unique_months:
            unique_months.append(yr_month)

        cat_id = t.category_id
        if cat_id not in cat_monthly_data:
            cat_monthly_data[cat_id] = {}

        if yr_month not in cat_monthly_data[cat_id]:
            cat_monthly_data[cat_id][yr_month] = 0.0

        cat_monthly_data[cat_id][yr_month] += t.amount

    if not unique_months:
        return {}

    # Map (year, month) to sequential index 1..N
    unique_months.sort()
    month_to_idx = {ym: i + 1 for i, ym in enumerate(unique_months)}
    total_months = len(unique_months)
    next_month_idx = total_months + 1

    predictions = {}

    for cat_id, data_by_month in cat_monthly_data.items():
        X = []
        y = []
        for ym in unique_months:
            idx = month_to_idx[ym]
            X.append([idx])
            y.append(data_by_month.get(ym, 0.0))

        if total_months < 2:
            # Fallback for insufficient data points (we need at least 2 points)
            avg = sum(y) / len(y) if len(y) > 0 else 0
            predicted_val = avg * 1.05
        else:
            # 1. Linear Regression (Extrapolation - Trend identification)
            reg = LinearRegression()
            reg.fit(X, y)
            predicted_val = float(reg.predict([[next_month_idx]])[0])

            # 2. Safety Net for Negatives
            if predicted_val < 0:
                predicted_val = sum(y) / len(y)

            # 3. Outlier Limits (Cap prediction if it spikes uncharacteristically)
            max_past_spend = max(y)
            avg_past_spend = sum(y) / len(y)

            upper_limit = max(max_past_spend * 1.5, avg_past_spend * 2.0)

            if predicted_val > upper_limit:
                predicted_val = upper_limit

            # Add 5% buffer
            predicted_val = predicted_val * 1.05

        predictions[str(cat_id)] = round(predicted_val, 2)

    return predictions


# ==========================================
# 5. AI INSIGHTS API
# ==========================================

@app.post("/insights/", response_model=schemas.AIInsightResponse)
def create_insight(insight: schemas.AIInsightCreate, user_id: int, db: Session = Depends(get_db),
                   current_user: models.User = Depends(get_current_user)):
    try:
        new_insight = models.AIInsight(
            user_id=user_id,
            insight_type=insight.insight_type,
            message=insight.message,
            is_read=insight.is_read
        )
        db.add(new_insight)
        db.commit()
        db.refresh(new_insight)
        return new_insight
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating insight: {str(e)}")


@app.get("/insights/user/{user_id}", response_model=list[schemas.AIInsightResponse])
def get_user_insights(user_id: int, db: Session = Depends(get_db),
                      current_user: models.User = Depends(get_current_user)):
    return db.query(models.AIInsight).filter(models.AIInsight.user_id == user_id).all()


@app.put("/insights/{insight_id}/read", response_model=schemas.AIInsightResponse)
def update_insight_read_status(insight_id: int, insight_update: schemas.AIInsightUpdate, db: Session = Depends(get_db),
                               current_user: models.User = Depends(get_current_user)):
    insight = db.query(models.AIInsight).filter(models.AIInsight.id == insight_id).first()
    if not insight:
        raise HTTPException(status_code=404, detail="Insight not found")

    if insight_update.is_read is not None:
        insight.is_read = insight_update.is_read

    db.commit()
    db.refresh(insight)
    return insight


@app.delete("/insights/{insight_id}")
def delete_insight(insight_id: int, db: Session = Depends(get_db),
                   current_user: models.User = Depends(get_current_user)):
    insight = db.query(models.AIInsight).filter(models.AIInsight.id == insight_id).first()
    if not insight:
        raise HTTPException(status_code=404, detail="Insight not found")
    db.delete(insight)
    db.commit()
    return {"message": "Insight deleted successfully"}