from datetime import date, timedelta


def today_str() -> str:
    return date.today().isoformat()


def days_from_today(days: int) -> str:
    return (date.today() + timedelta(days=days)).isoformat()
