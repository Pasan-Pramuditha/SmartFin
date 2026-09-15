# SmartFin - Personal Finance & Budgeting App

SmartFin is a personal finance management application built with **Flutter** for the mobile frontend and **FastAPI** (Python) for the backend. It features Machine Learning capabilities for automated expense categorization, secure authentication (JWT, 2FA, Social Logins), and detailed financial insights.

## System Architecture
*   **Frontend:** Flutter (Dart)
*   **Backend:** FastAPI (Python)
*   **Database:** PostgreSQL
*   **Machine Learning:** Scikit-Learn (NLP categorization)

---

## Prerequisites
Before you begin, ensure you have the following installed on your machine:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.10+)
*   [Python](https://www.python.org/downloads/) (Version 3.10+)
*   [PostgreSQL](https://www.postgresql.org/download/)

---

## 1. Database Setup

1.  Open your PostgreSQL tool (pgAdmin or command line).
2.  Create a new database named `smartfin_db`.
3.  Ensure your PostgreSQL credentials match the ones in `smartfin backend/database.py`. The default configuration is:
    ```python
    SQLALCHEMY_DATABASE_URL = "postgresql://postgres:pasan1234@localhost:5432/smartfin_db"
    ```
    *(If your password or username is different, update this file accordingly).*
    *Note: The FastAPI backend uses SQLAlchemy to automatically create the required database tables on startup.*

---

## 2. Backend Setup (FastAPI)

1.  Open a terminal and navigate to the backend folder:
    ```bash
    cd "smartfin backend"
    ```
2.  Install the required Python dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3.  **Environment Variables:** Create a `.env` file inside the `smartfin backend` folder and add your Gmail credentials for sending OTP and password reset emails:
    ```env
    SMTP_EMAIL=your_email@gmail.com
    SMTP_PASSWORD=your_google_app_password
    ```
    *(You can generate an App Password from your Google Account Security settings).*
4.  **Train the Machine Learning Model:** Before starting the server for the first time, you must train the NLP model that categorizes expenses:
    ```bash
    python train_model.py
    ```
5.  **Run the Server:** Start the FastAPI backend server:
    ```bash
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    ```
    The backend will now be running on `http://localhost:8000`.

---

## 3. Frontend Setup (Flutter)

1.  Open a new terminal and navigate to the frontend folder:
    ```bash
    cd smartfin
    ```
2.  Install all the Flutter packages:
    ```bash
    flutter pub get
    ```
3.  **Configure API URL:** Open the file `lib/services/api_service.dart`. You must set the `baseUrl` depending on how you are testing the app:
    *   **Android Emulator:** Use `http://10.0.2.2:8000`
    *   **Physical Device:** Use your computer's local Wi-Fi IPv4 address (e.g., `http://192.168.1.x:8000`)
4.  **Run the App:** Connect your device or emulator and run:
    ```bash
    flutter run
    ```

---

## Troubleshooting
*   **Network Error on Physical Device:** Ensure your phone and computer are on the **exact same Wi-Fi network**, turn off mobile data on the phone, and temporarily disable the Windows Defender Firewall (Private Network) if it blocks port 8000.
*   **Social Login Not Working:** Ensure the `GOOGLE_CLIENT_ID` in `main.py` and the Flutter configuration matches your Firebase/Google Cloud Console setup.
