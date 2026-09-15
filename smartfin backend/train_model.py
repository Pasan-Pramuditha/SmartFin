import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
import pickle
import re


def clean_text_local(text: str):
    text = str(text).lower()
    return re.sub(r'[^a-z0-9\s]', '', text).strip()


def train_and_save_model():
    print("Loading dataset...")
    try:
        df = pd.read_csv("transaction_dataset.csv")
        if 'title' not in df.columns:
            # Fallback for tab-separated
            df = pd.read_csv("transaction_dataset.csv", sep='\t')
    except pd.errors.ParserError:
        df = pd.read_csv("transaction_dataset.csv", sep='\t')

    print("Cleaning data...")
    df['title_clean'] = df['title'].apply(clean_text_local)

    print("Training vectorizer and model...")
    vectorizer = TfidfVectorizer(stop_words='english', max_features=1000, ngram_range=(1, 2))
    x_features = vectorizer.fit_transform(df['title_clean'])
    y_target = df['category']

    model = MultinomialNB(fit_prior=False)
    model.fit(x_features, y_target)

    print("Saving model and vectorizer...")
    with open("category_model.pkl", "wb") as f:
        pickle.dump(model, f)

    with open("vectorizer.pkl", "wb") as f:
        pickle.dump(vectorizer, f)

    print("Model training complete. Files saved as category_model.pkl and vectorizer.pkl.")


if __name__ == "__main__":
    train_and_save_model()