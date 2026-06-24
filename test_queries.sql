-- ============================================
-- ТЕСТОВЫЕ ЗАПРОСЫ ДЛЯ ПРОВЕРКИ БД
-- Car Analytics Database
-- Курсовой проект МДК.11.01
-- ============================================

-- ============================================
-- РАЗДЕЛ 1: ПРОВЕРКА СТРУКТУРЫ БД
-- ============================================

-- 1.1. Список всех таблиц в БД
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 1.2. Список всех представлений (VIEW)
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'public'
ORDER BY table_name;

-- 1.3. Список всех пользовательских функций
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
ORDER BY routine_name;

-- 1.4. Список всех хранимых процедур
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' AND routine_type = 'PROCEDURE'
ORDER BY routine_name;

-- 1.5. Список всех триггеров
SELECT trigger_name, event_object_table, event_manipulation, action_timing
FROM information_schema.triggers 
WHERE trigger_schema = 'public'
ORDER BY trigger_name;

-- 1.6. Список всех ролей пользователей
SELECT rolname, rolsuper, rolcreaterol, rolcreatedb, rolcanlogin
FROM pg_catalog.pg_roles
WHERE rolname IN ('app_user', 'service_user', 'car_admin');

-- ============================================
-- РАЗДЕЛ 2: ПРОВЕРКА ДАННЫХ
-- ============================================

-- 2.1. Подсчёт записей во всех таблицах
SELECT 
    (SELECT COUNT(*) FROM error_categories) AS categories_count,
    (SELECT COUNT(*) FROM errors) AS errors_count,
    (SELECT COUNT(*) FROM cars) AS cars_count,
    (SELECT COUNT(*) FROM car_errors) AS car_errors_count,
    (SELECT COUNT(*) FROM users) AS users_count,
    (SELECT COUNT(*) FROM favorites) AS favorites_count,
    (SELECT COUNT(*) FROM service_records) AS service_records_count,
    (SELECT COUNT(*) FROM notifications) AS notifications_count;

-- 2.2. Просмотр категорий ошибок
SELECT id, name, name_en, icon, color FROM error_categories ORDER BY sort_order;

-- 2.3. Просмотр машин (первые 10)
SELECT id, brand, model, year, engine_type, fuel_type, country 
FROM cars 
ORDER BY brand, model
LIMIT 10;

-- 2.4. Просмотр ошибок (первые 10)
SELECT id, code, title, severity, estimated_cost_rub, category_id 
FROM errors 
ORDER BY code
LIMIT 10;

-- 2.5. Просмотр пользователей
SELECT id, email, username, device_type, created_at 
FROM users 
ORDER BY created_at;

-- ============================================
-- РАЗДЕЛ 3: ТИПОВЫЕ ЗАПРОСЫ (БИЗНЕС-ЛОГИКА)
-- ============================================

-- 3.1. Все ошибки для конкретной машины (по ID)
SELECT * FROM vw_car_errors_full WHERE car_id = 1;

-- 3.2. Топ-10 самых частых ошибок по марке
SELECT error_code, error_title, AVG(frequency) AS avg_freq
FROM vw_car_errors_full
WHERE brand = 'Toyota'
GROUP BY error_code, error_title
ORDER BY avg_freq DESC
LIMIT 10;

-- 3.3. Статистика ошибок по категориям
SELECT category_name, COUNT(*) AS error_count, AVG(frequency) AS avg_frequency
FROM vw_car_errors_full
GROUP BY category_name
ORDER BY error_count DESC;

-- 3.4. Поиск ошибок по коду (с LIKE)
SELECT * FROM errors WHERE code LIKE 'P01%';

-- 3.5. Машины с самыми дорогими ошибками
SELECT brand, model, SUM(estimated_cost_rub) AS total_potential_cost
FROM vw_car_errors_full
GROUP BY brand, model
ORDER BY total_potential_cost DESC
LIMIT 5;

-- 3.6. Ошибки высокой серьёзности
SELECT code, title, severity, estimated_cost_rub
FROM errors
WHERE severity = 'high'
ORDER BY estimated_cost_rub DESC;

-- ============================================
-- РАЗДЕЛ 4: ТЕСТИРОВАНИЕ ФУНКЦИЙ
-- ============================================

-- 4.1. Тестирование функции get_error_stats
-- Возвращает статистику ошибок по категориям для машины с ID=1
SELECT * FROM get_error_stats(1);

-- 4.2. Тестирование функции get_user_favorite_count
-- Подсчитывает количество избранных ошибок пользователя
SELECT get_user_favorite_count(
    (SELECT id FROM users WHERE username = 'demo_user')
);

-- 4.3. Тестирование функции calculate_repair_score
-- Рассчитывает индекс сложности ремонта для ошибки с ID=1
SELECT calculate_repair_score(1);

-- 4.4. Тестирование calculate_repair_score для нескольких ошибок
SELECT 
    e.code,
    e.title,
    calculate_repair_score(e.id) AS repair_score
FROM errors e
WHERE e.id IN (1, 8, 15, 24)
ORDER BY repair_score DESC;

-- ============================================
-- РАЗДЕЛ 5: ТЕСТИРОВАНИЕ ПРОЦЕДУР
-- ============================================

-- 5.1. Тестирование процедуры add_service_record
-- Добавляет запись в сервисную историю
CALL add_service_record(
    (SELECT id FROM users WHERE username = 'demo_user')::UUID,
    1,
    50000,
    'Замена масла',
    5000.00,
    'Автосервис "Мотор"'
);

-- Проверка результата
SELECT * FROM service_records ORDER BY created_at DESC LIMIT 5;

-- 5.2. Тестирование процедуры add_multiple_favorites
-- Массовое добавление ошибок в избранное
CALL add_multiple_favorites(
    (SELECT id FROM users WHERE username = 'demo_user')::UUID,
    ARRAY[1, 2, 3, 5, 8],
    'Тестовые ошибки'
);

-- Проверка результата
SELECT * FROM favorites ORDER BY created_at DESC LIMIT 10;

-- 5.3. Тестирование процедуры archive_old_notifications
-- Архивация старых уведомлений (старше 30 дней)
CALL archive_old_notifications(30);

-- ============================================
-- РАЗДЕЛ 6: ТЕСТИРОВАНИЕ ПРЕДСТАВЛЕНИЙ (VIEW)
-- ============================================

-- 6.1. Проверка VIEW vw_car_errors_full
SELECT * FROM vw_car_errors_full LIMIT 10;

-- 6.2. Проверка VIEW vw_user_favorites
SELECT * FROM vw_user_favorites;

-- 6.3. Проверка VIEW vw_service_statistics
SELECT * FROM vw_service_statistics;

-- ============================================
-- РАЗДЕЛ 7: ТЕСТИРОВАНИЕ ТРИГГЕРОВ
-- ============================================

-- 7.1. Проверка триггера обновления updated_at
-- Запоминаем текущее значение
SELECT id, title, updated_at FROM errors WHERE id = 1;

-- Обновляем запись
UPDATE errors SET title = 'Тестовое обновление' WHERE id = 1;

-- Проверяем, что updated_at изменился
SELECT id, title, updated_at FROM errors WHERE id = 1;

-- Возвращаем оригинальное значение
UPDATE errors SET title = 'Неисправность MAF' WHERE id = 1;

-- 7.2. Проверка триггера валидации кода ошибки
-- Этот запрос ДОЛЖЕН вызвать ошибку (неверный формат кода)
-- INSERT INTO errors (code, title, description) 
-- VALUES ('X1234', 'Test', 'Test');

-- Этот запрос ДОЛЖЕН пройти успешно (правильный формат)
-- INSERT INTO errors (code, title, description) 
-- VALUES ('P9999', 'Test Error', 'Test Description');
-- DELETE FROM errors WHERE code = 'P9999';

-- ============================================
-- РАЗДЕЛ 8: ПРОВЕРКА ПРАВ ДОСТУПА
-- ============================================

-- 8.1. Проверка прав app_user
-- (выполняется от имени app_user)
-- SELECT * FROM cars LIMIT 5;  -- Должно работать
-- SELECT * FROM users;         -- Должно вызвать ошибку

-- 8.2. Проверка прав service_user
-- (выполняется от имени service_user)
-- SELECT * FROM vw_service_statistics;  -- Должно работать

-- ============================================
-- РАЗДЕЛ 9: КОМПЛЕКСНЫЕ ЗАПРОСЫ
-- ============================================

-- 9.1. Полный отчёт по машине (все данные)
SELECT 
    c.brand,
    c.model,
    c.year,
    COUNT(ce.error_id) AS total_errors,
    AVG(ce.frequency) AS avg_frequency,
    SUM(e.estimated_cost_rub) AS total_repair_cost,
    MAX(e.severity) AS max_severity
FROM cars c
LEFT JOIN car_errors ce ON c.id = ce.car_id
LEFT JOIN errors e ON ce.error_id = e.id
GROUP BY c.id, c.brand, c.model, c.year
ORDER BY total_repair_cost DESC;

-- 9.2. Распределение ошибок по странам производства
SELECT 
    c.country,
    COUNT(DISTINCT c.id) AS cars_count,
    COUNT(ce.error_id) AS total_errors,
    AVG(e.estimated_cost_rub) AS avg_repair_cost
FROM cars c
LEFT JOIN car_errors ce ON c.id = ce.car_id
LEFT JOIN errors e ON ce.error_id = e.id
GROUP BY c.country
ORDER BY total_errors DESC;

-- 9.3. Ошибки, встречающиеся у нескольких машин
SELECT 
    e.code,
    e.title,
    COUNT(ce.car_id) AS affected_cars,
    AVG(ce.frequency) AS avg_frequency
FROM errors e
JOIN car_errors ce ON e.id = ce.error_id
GROUP BY e.id, e.code, e.title
HAVING COUNT(ce.car_id) > 1
ORDER BY affected_cars DESC;

-- 9.4. Сервисная история с деталями
SELECT 
    u.username,
    c.brand || ' ' || c.model AS car,
    sr.service_type,
    sr.cost,
    sr.service_date,
    sr.service_center
FROM service_records sr
JOIN users u ON sr.user_id = u.id
JOIN cars c ON sr.car_id = c.id
ORDER BY sr.service_date DESC;

-- 9.5. Уведомления пользователей
SELECT 
    u.username,
    n.title,
    n.message,
    n.type,
    n.is_read,
    n.sent_at
FROM notifications n
JOIN users u ON n.user_id = u.id
ORDER BY n.sent_at DESC
LIMIT 10;

-- ============================================
-- РАЗДЕЛ 10: ФИНАЛЬНАЯ ПРОВЕРКА
-- ============================================

-- 10.1. Итоговая статистика
SELECT 
    'Таблицы' AS object_type,
    COUNT(*) AS count
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'

UNION ALL

SELECT 
    'Представления' AS object_type,
    COUNT(*) AS count
FROM information_schema.views 
WHERE table_schema = 'public'

UNION ALL

SELECT 
    'Функции' AS object_type,
    COUNT(*) AS count
FROM information_schema.routines 
WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'

UNION ALL

SELECT 
    'Процедуры' AS object_type,
    COUNT(*) AS count
FROM information_schema.routines 
WHERE routine_schema = 'public' AND routine_type = 'PROCEDURE'

UNION ALL

SELECT 
    'Триггеры' AS object_type,
    COUNT(*) AS count
FROM information_schema.triggers 
WHERE trigger_schema = 'public';

-- 10.2. Проверка нормальных форм (3NF)
-- Все таблицы должны иметь первичный ключ
-- Все не-ключевые атрибуты должны зависеть только от первичного ключа
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- ============================================
-- КОНЕЦ ТЕСТОВЫХ ЗАПРОСОВ
-- ============================================