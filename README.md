# SmartFin – Personal Finance & Expense Tracker with AI Insights

SmartFin is a personal finance management application built with **Flutter** for the mobile frontend and **FastAPI** (Python) for the backend. It features Machine Learning capabilities for automated expense categorization, secure authentication (JWT, 2FA, Social Logins), and detailed financial insights.

## System Architecture
*   **Frontend:** Flutter (Dart)
*   **Backend:** FastAPI (Python)
*   **Database:** PostgreSQL
*   **Machine Learning:** Scikit-Learn (NLP categorization)

---

## Key Features
*   **AI-Powered Categorization:** Automatically categorizes your expenses using NLP Machine Learning.
*   **Secure Authentication:** Supports Email/Password, Biometric Login (Fingerprint/FaceID), and Social Logins (Google & Facebook).
*   **Two-Factor Authentication (2FA):** Enhanced security with email-based OTP verification and Password Recovery.
*   **Budget Management:** Set monthly budgets for different categories and track your spending limits.
*   **Multi-Currency Support:** Handle your finances and transactions in multiple currencies.
*   **Financial Insights:** Visualizes income and expenses with interactive charts (Daily/Weekly/Monthly analysis).
*   **Export Reports:** Generate and download detailed financial reports in PDF and Excel formats.
*   **Customizable UI:** Built-in support for Dark and Light modes.

---

## Prerequisites
Before you begin, ensure you have the following installed on your machine:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.10+)
*   [Python](https://www.python.org/downloads/) (Version 3.10+)
*   [PostgreSQL](https://www.postgresql.org/download/)

---

## 1. Database Setup

The easiest way to set up the PostgreSQL database is using **Docker**. A `docker-compose.yml` file is provided in the backend directory.

1.  Make sure you have [Docker Desktop](https://www.docker.com/products/docker-desktop) installed and running.
2.  Open a terminal and navigate to the backend folder:
    ```bash
    cd "smartfin backend"
    ```
3.  Run the following command to download and start the database:
    ```bash
    docker-compose up -d
    ```
    This will automatically create a PostgreSQL database named `smartfin_db` with the correct username and password (`postgres` / `pasan1234`) on port 5432.

*(Alternatively, you can manually install PostgreSQL and create the database yourself using the credentials found in `smartfin backend/database.py`).*

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
    *(This command acts like a shopping list. It automatically downloads and installs all the external libraries, such as FastAPI and scikit-learn, needed to run the backend).*
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
*   **Social Login Not Working:** Ensure the `GOOGLE_CLIENT_ID` in `main.py` and the Flutter configuration matches your Firebase/Google Cloud Console setup.

---

<div align="center">
  <b>Created By Pasan Pramuditha</b>
</div>
