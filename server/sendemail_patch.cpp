void sendEmail(const QString& to, const QString& subject, const QString& body) {
    qDebug() << "========================================";
    qDebug() << "📧 Email to:" << to;
    qDebug() << "   Subject:" << subject;
    qDebug() << "   Body:" << body;
    qDebug() << "========================================";

    // Для теста: извлекаем код из тела письма
    QRegularExpression re("(\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    if (match.hasMatch()) {
        qDebug() << "🔑 КОД ДЛЯ ВОССТАНОВЛЕНИЯ:" << match.captured(1);
        qDebug() << "========================================";
    }
}
