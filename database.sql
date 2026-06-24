-- ============================================
-- CAR ANALYTICS DATABASE
-- Курсовой проект по МДК.11.01
-- Технология разработки и защиты баз данных
-- Версия: 3.0 (полная, соответствует требованиям)
-- Кодировка: UTF-8
-- СУБД: PostgreSQL 14+
-- ============================================

-- Очистка (если БД уже существует)
DROP DATABASE IF EXISTS car_analytics;
CREATE DATABASE car_analytics ENCODING 'UTF8';
\c car_analytics

-- ============================================
-- 1. СОЗДАНИЕ РОЛЕЙ ПОЛЬЗОВАТЕЛЕЙ
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user WITH LOGIN PASSWORD 'app_user_password_2026';
    END IF;
    
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_user') THEN
        CREATE ROLE service_user WITH LOGIN PASSWORD 'service_user_password_2026';
    END IF;
    
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'car_admin') THEN
        CREATE ROLE car_admin WITH LOGIN PASSWORD 'admin_password_2026' CREATEDB;
    END IF;
END $$;

-- ============================================
-- 2. СОЗДАНИЕ ТАБЛИЦ (3NF)
-- ============================================

-- Таблица 1: Категории ошибок
CREATE TABLE error_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    name_en VARCHAR(100) UNIQUE NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(20),
    description TEXT,
    sort_order INTEGER DEFAULT 0
);

-- Таблица 2: Ошибки OBD2
CREATE TABLE errors (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    title_en VARCHAR(255),
    description TEXT NOT NULL,
    symptoms TEXT,
    causes TEXT,
    solutions TEXT,
    severity VARCHAR(20) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    repair_complexity VARCHAR(20) DEFAULT 'medium',
    estimated_cost_rub DECIMAL(10,2),
    category_id INTEGER REFERENCES error_categories(id) ON DELETE SET NULL,
    obd2_standard BOOLEAN DEFAULT TRUE,
    pdf_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица 3: Машины
CREATE TABLE cars (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INTEGER NOT NULL CHECK (year >= 1900 AND year <= EXTRACT(YEAR FROM NOW()) + 1),
    vin VARCHAR(17) UNIQUE,
    engine_type VARCHAR(50),
    engine_volume DECIMAL(3,1),
    power_hp INTEGER,
    transmission VARCHAR(50),
    drive_type VARCHAR(50),
    fuel_type VARCHAR(50),
    body_type VARCHAR(50),
    image_url TEXT,
    country VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(brand, model, year)
);

-- Таблица 4: Связь машина-ошибка (многие-ко-многим)
CREATE TABLE car_errors (
    car_id INTEGER REFERENCES cars(id) ON DELETE CASCADE,
    error_id INTEGER REFERENCES errors(id) ON DELETE CASCADE,
    frequency INTEGER DEFAULT 50 CHECK (frequency BETWEEN 0 AND 100),
    specific_notes TEXT,
    PRIMARY KEY (car_id, error_id)
);

-- Таблица 5: Пользователи
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    phone VARCHAR(20),
    avatar_url TEXT,
    device_id VARCHAR(255),
    device_type VARCHAR(50) DEFAULT 'mobile',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица 6: Избранное пользователя
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(255),
    error_id INTEGER REFERENCES errors(id) ON DELETE CASCADE,
    note TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, error_id)
);

-- Таблица 7: Сервисная история
CREATE TABLE service_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    car_id INTEGER REFERENCES cars(id) ON DELETE CASCADE,
    mileage INTEGER CHECK (mileage >= 0),
    service_type VARCHAR(100) NOT NULL,
    description TEXT,
    cost DECIMAL(10,2) CHECK (cost >= 0),
    service_date DATE NOT NULL,
    service_center VARCHAR(255),
    next_service_mileage INTEGER,
    next_service_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Таблица 8: Уведомления
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'info' CHECK (type IN ('info', 'warning', 'error', 'success')),
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. ИНДЕКСЫ (оптимизация запросов)
-- ============================================
CREATE INDEX idx_errors_code ON errors(code);
CREATE INDEX idx_errors_category ON errors(category_id);
CREATE INDEX idx_errors_severity ON errors(severity);
CREATE INDEX idx_cars_brand ON cars(brand);
CREATE INDEX idx_cars_model ON cars(model);
CREATE INDEX idx_cars_year ON cars(year);
CREATE INDEX idx_car_errors_car ON car_errors(car_id);
CREATE INDEX idx_car_errors_error ON car_errors(error_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_device ON users(device_id);
CREATE INDEX idx_favorites_user ON favorites(user_id);
CREATE INDEX idx_favorites_error ON favorites(error_id);
CREATE INDEX idx_service_user ON service_records(user_id);
CREATE INDEX idx_service_car ON service_records(car_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- ============================================
-- 4. ПРЕДСТАВЛЕНИЯ (VIEW) - 3 штуки
-- ============================================

-- VIEW 1: Полная информация об ошибках машин
CREATE OR REPLACE VIEW vw_car_errors_full AS
SELECT 
    c.id AS car_id,
    c.brand,
    c.model,
    c.year,
    c.fuel_type,
    e.id AS error_id,
    e.code AS error_code,
    e.title AS error_title,
    e.severity,
    e.estimated_cost_rub,
    ec.name AS category_name,
    ec.color AS category_color,
    ce.frequency
FROM cars c
JOIN car_errors ce ON c.id = ce.car_id
JOIN errors e ON ce.error_id = e.id
JOIN error_categories ec ON e.category_id = ec.id;

-- VIEW 2: Избранное пользователей с деталями
CREATE OR REPLACE VIEW vw_user_favorites AS
SELECT 
    f.id AS favorite_id,
    u.username,
    u.email,
    e.code AS error_code,
    e.title AS error_title,
    e.severity,
    f.note,
    f.is_read,
    f.created_at AS added_at
FROM favorites f
JOIN users u ON f.user_id = u.id
JOIN errors e ON f.error_id = e.id;

-- VIEW 3: Статистика сервисного обслуживания
CREATE OR REPLACE VIEW vw_service_statistics AS
SELECT 
    c.brand,
    c.model,
    COUNT(sr.id) AS total_services,
    COALESCE(SUM(sr.cost), 0) AS total_cost,
    COALESCE(AVG(sr.cost), 0) AS avg_cost,
    MAX(sr.service_date) AS last_service,
    MAX(sr.mileage) AS max_mileage
FROM service_records sr
JOIN cars c ON sr.car_id = c.id
GROUP BY c.brand, c.model;

-- ============================================
-- 5. ПОЛЬЗОВАТЕЛЬСКИЕ ФУНКЦИИ - 3 штуки
-- ============================================

-- Функция 1: Подсчёт статистики ошибок по машине
CREATE OR REPLACE FUNCTION get_error_stats(p_car_id INTEGER)
RETURNS TABLE(category_name VARCHAR, error_count BIGINT, avg_frequency NUMERIC) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_errors INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_errors 
    FROM car_errors WHERE car_id = p_car_id;
    
    IF v_total_errors = 0 THEN
        RAISE NOTICE 'Для машины с ID=% ошибок не найдено', p_car_id;
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        ec.name AS category_name,
        COUNT(*) AS error_count,
        ROUND(AVG(ce.frequency), 2) AS avg_frequency
    FROM car_errors ce
    JOIN errors e ON ce.error_id = e.id
    JOIN error_categories ec ON e.category_id = ec.id
    WHERE ce.car_id = p_car_id
    GROUP BY ec.name
    ORDER BY error_count DESC;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка в get_error_stats: %', SQLERRM;
        RETURN;
END;
$$;

-- Функция 2: Подсчёт избранного пользователя
CREATE OR REPLACE FUNCTION get_user_favorite_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
    v_username VARCHAR;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM favorites WHERE user_id = p_user_id;
    
    SELECT username INTO v_username
    FROM users WHERE id = p_user_id;
    
    IF v_username IS NULL THEN
        RAISE EXCEPTION 'Пользователь с ID=% не найден', p_user_id;
    END IF;
    
    RAISE NOTICE 'Пользователь % имеет % избранных ошибок', v_username, v_count;
    
    RETURN v_count;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE NOTICE 'Данные не найдены для пользователя %', p_user_id;
        RETURN 0;
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка: %', SQLERRM;
        RETURN 0;
END;
$$;

-- Функция 3: Расчёт индекса сложности ремонта
CREATE OR REPLACE FUNCTION calculate_repair_score(p_error_id INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_severity_score NUMERIC := 0;
    v_complexity_score NUMERIC := 0;
    v_cost_score NUMERIC := 0;
    v_final_score NUMERIC;
    v_error_code VARCHAR;
BEGIN
    SELECT code, severity, repair_complexity, estimated_cost_rub
    INTO v_error_code
    FROM errors WHERE id = p_error_id;
    
    IF v_error_code IS NULL THEN
        RAISE EXCEPTION 'Ошибка с ID=% не найдена', p_error_id;
    END IF;
    
    SELECT CASE severity
        WHEN 'low' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'high' THEN 3
        WHEN 'critical' THEN 5
        ELSE 0
    END INTO v_severity_score
    FROM errors WHERE id = p_error_id;
    
    SELECT CASE repair_complexity
        WHEN 'easy' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'hard' THEN 4
        ELSE 0
    END INTO v_complexity_score
    FROM errors WHERE id = p_error_id;
    
    SELECT LEAST(COALESCE(estimated_cost_rub, 0) / 10000, 5)
    INTO v_cost_score
    FROM errors WHERE id = p_error_id;
    
    v_final_score := v_severity_score + v_complexity_score + v_cost_score;
    
    RETURN ROUND(v_final_score, 2);
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка расчёта: %', SQLERRM;
        RETURN 0;
END;
$$;

-- ============================================
-- 6. ТРИГГЕРЫ - 3 штуки
-- ============================================

-- Триггерная функция 1: Автоматическое обновление updated_at
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка в триггере: %', SQLERRM;
        RETURN OLD;
END;
$$;

-- Триггер 1: Для таблицы errors
CREATE TRIGGER trg_errors_update
BEFORE UPDATE ON errors
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- Триггер 2: Для таблицы users
CREATE TRIGGER trg_users_update
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- Триггерная функция 2: Валидация кода ошибки
CREATE OR REPLACE FUNCTION fn_validate_error_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_code_pattern TEXT;
BEGIN
    IF NEW.code !~ '^[PCBU][0-9]{4}$' THEN
        RAISE EXCEPTION 'Неверный формат кода ошибки: %. Ожидается формат P0XXX, C0XXX, B0XXX или U0XXX', NEW.code;
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка валидации: %', SQLERRM;
        RAISE;
END;
$$;

-- Триггер 3: Валидация при вставке/обновлении ошибки
CREATE TRIGGER trg_validate_error_code
BEFORE INSERT OR UPDATE ON errors
FOR EACH ROW
EXECUTE FUNCTION fn_validate_error_code();

-- ============================================
-- 7. ХРАНИМЫЕ ПРОЦЕДУРЫ - 3 штуки
-- ============================================

-- Процедура 1: Добавление сервисной записи (с транзакцией)
CREATE OR REPLACE PROCEDURE add_service_record(
    p_user_id UUID,
    p_car_id INTEGER,
    p_mileage INTEGER,
    p_service_type VARCHAR,
    p_cost DECIMAL,
    p_service_center VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record_id UUID;
    v_next_mileage INTEGER;
    v_next_date DATE;
    v_user_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'Пользователь с ID=% не найден', p_user_id;
    END IF;
    
    INSERT INTO service_records (
        user_id, car_id, mileage, service_type, cost, service_date, service_center
    ) VALUES (
        p_user_id, p_car_id, p_mileage, p_service_type, p_cost, CURRENT_DATE, p_service_center
    ) RETURNING id INTO v_record_id;
    
    v_next_mileage := p_mileage + 10000;
    v_next_date := CURRENT_DATE + INTERVAL '6 months';
    
    UPDATE service_records 
    SET next_service_mileage = v_next_mileage,
        next_service_date = v_next_date
    WHERE id = v_record_id;
    
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
        p_user_id,
        'Сервисная запись добавлена',
        format('Запись %s на пробеге %s км успешно добавлена', p_service_type, p_mileage),
        'success'
    );
    
    COMMIT;
    
    RAISE NOTICE 'Сервисная запись % успешно создана', v_record_id;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE NOTICE 'Ошибка при создании записи: %', SQLERRM;
        RAISE;
END;
$$;

-- Процедура 2: Массовое добавление ошибок в избранное
CREATE OR REPLACE PROCEDURE add_multiple_favorites(
    p_user_id UUID,
    p_error_ids INTEGER[],
    p_note TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_id INTEGER;
    v_added_count INTEGER := 0;
    v_skipped_count INTEGER := 0;
BEGIN
    FOREACH v_error_id IN ARRAY p_error_ids
    LOOP
        BEGIN
            INSERT INTO favorites (user_id, error_id, note)
            VALUES (p_user_id, v_error_id, p_note)
            ON CONFLICT (user_id, error_id) DO NOTHING;
            
            IF FOUND THEN
                v_added_count := v_added_count + 1;
            ELSE
                v_skipped_count := v_skipped_count + 1;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_skipped_count := v_skipped_count + 1;
                RAISE NOTICE 'Ошибка добавления ошибки %: %', v_error_id, SQLERRM;
        END;
    END LOOP;
    
    COMMIT;
    
    RAISE NOTICE 'Добавлено: %, пропущено: %', v_added_count, v_skipped_count;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE NOTICE 'Критическая ошибка: %', SQLERRM;
        RAISE;
END;
$$;

-- Процедура 3: Архивация старых уведомлений
CREATE OR REPLACE PROCEDURE archive_old_notifications(
    p_days_old INTEGER DEFAULT 30
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cutoff_date TIMESTAMP;
    v_deleted_count INTEGER;
BEGIN
    v_cutoff_date := NOW() - (p_days_old || ' days')::INTERVAL;
    
    DELETE FROM notifications
    WHERE sent_at < v_cutoff_date AND is_read = TRUE;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    COMMIT;
    
    RAISE NOTICE 'Архивировано % уведомлений старше % дней', v_deleted_count, p_days_old;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE NOTICE 'Ошибка архивации: %', SQLERRM;
        RAISE;
END;
$$;

-- ============================================
-- 8. НАЗНАЧЕНИЕ ПРАВ РОЛЯМ
-- ============================================

GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT ON cars, errors, error_categories, vw_car_errors_full TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON favorites, service_records, notifications TO app_user;
GRANT SELECT ON vw_user_favorites TO app_user;
GRANT USAGE ON SEQUENCE cars_id_seq, errors_id_seq, error_categories_id_seq TO app_user;

GRANT USAGE ON SCHEMA public TO service_user;
GRANT SELECT ON ALL TABLES TO service_user;
GRANT SELECT ON vw_service_statistics TO service_user;
GRANT EXECUTE ON FUNCTION get_error_stats(INTEGER) TO service_user;
GRANT EXECUTE ON FUNCTION get_user_favorite_count(UUID) TO service_user;
GRANT EXECUTE ON FUNCTION calculate_repair_score(INTEGER) TO service_user;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO car_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO car_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO car_admin;

-- ============================================
-- 9. SEED ДАННЫЕ
-- ============================================

-- Категории ошибок
INSERT INTO error_categories (name, name_en, icon, color, description, sort_order) VALUES
('Двигатель', 'Engine', '🔥', '#ef4444', 'Ошибки двигателя и системы управления', 1),
('Трансмиссия', 'Transmission', '🔧', '#f97316', 'Ошибки КПП и трансмиссии', 2),
('Электрика', 'Electrical', '⚡', '#eab308', 'Ошибки электрической системы', 3),
('Тормозная система', 'Brakes', '🛑', '#dc2626', 'Ошибки тормозной системы', 4),
('Подвеска', 'Suspension', '🔩', '#8b5cf6', 'Ошибки подвески', 5),
('Выхлопная система', 'Exhaust', '💨', '#6b7280', 'Ошибки выхлопной системы', 6),
('Климат', 'Climate', '❄️', '#06b6d4', 'Ошибки климат-контроля', 7),
('Безопасность', 'Safety', '🛡️', '#10b981', 'Ошибки систем безопасности', 8),
('Кузов', 'Body', '🚗', '#64748b', 'Ошибки кузовных систем', 9),
('Другое', 'Other', '❓', '#94a3b8', 'Прочие ошибки', 10);

-- Машины (20 штук)
INSERT INTO cars (brand, model, year, engine_type, engine_volume, power_hp, transmission, drive_type, fuel_type, body_type, country) VALUES
('Audi', 'A4', 2020, 'Turbo', 2.0, 190, 'S tronic', 'FWD', 'Petrol', 'Sedan', 'Germany'),
('BMW', '3 Series', 2021, 'Turbo', 2.0, 184, 'ZF 8HP', 'RWD', 'Petrol', 'Sedan', 'Germany'),
('Mercedes-Benz', 'C-Class', 2021, 'Turbo', 1.5, 204, '9G-Tronic', 'RWD', 'Petrol', 'Sedan', 'Germany'),
('Toyota', 'Camry', 2022, 'Atmo', 2.5, 200, 'Automatic', 'FWD', 'Petrol', 'Sedan', 'Japan'),
('Toyota', 'RAV4', 2022, 'Hybrid', 2.5, 222, 'e-CVT', 'AWD', 'Hybrid', 'SUV', 'Japan'),
('Honda', 'CR-V', 2022, 'Turbo', 1.5, 190, 'CVT', 'AWD', 'Petrol', 'SUV', 'Japan'),
('Kia', 'Sportage', 2022, 'Turbo', 1.6, 180, 'DCT', 'AWD', 'Petrol', 'SUV', 'Korea'),
('Hyundai', 'Tucson', 2022, 'Turbo', 1.6, 180, 'DCT', 'AWD', 'Petrol', 'SUV', 'Korea'),
('Ford', 'Focus', 2020, 'Ecoboost', 1.5, 150, 'Automatic', 'FWD', 'Petrol', 'Hatchback', 'USA'),
('Volkswagen', 'Tiguan', 2021, 'TSI', 2.0, 180, 'DSG', 'AWD', 'Petrol', 'SUV', 'Germany'),
('Nissan', 'X-Trail', 2022, 'Atmo', 2.5, 171, 'CVT', 'AWD', 'Petrol', 'SUV', 'Japan'),
('Mazda', 'CX-5', 2022, 'Atmo', 2.5, 194, 'Automatic', 'AWD', 'Petrol', 'SUV', 'Japan'),
('Lada', 'Vesta', 2022, 'Atmo', 1.6, 106, 'Manual', 'FWD', 'Petrol', 'Sedan', 'Russia'),
('Volvo', 'XC60', 2022, 'Turbo', 2.0, 249, 'Automatic', 'AWD', 'Petrol', 'SUV', 'Sweden'),
('Subaru', 'Forester', 2022, 'Boxer', 2.5, 182, 'CVT', 'AWD', 'Petrol', 'SUV', 'Japan'),
('Geely', 'Atlas Pro', 2022, 'Turbo', 1.5, 177, 'DCT', 'AWD', 'Petrol', 'SUV', 'China'),
('Haval', 'F7', 2022, 'Turbo', 2.0, 190, 'DCT', 'AWD', 'Petrol', 'SUV', 'China'),
('Peugeot', '3008', 2022, 'Turbo', 1.6, 180, 'Automatic', 'FWD', 'Petrol', 'SUV', 'France'),
('Renault', 'Duster', 2022, 'Atmo', 2.0, 143, 'Automatic', 'AWD', 'Petrol', 'SUV', 'France'),
('Land Rover', 'Range Rover', 2022, 'V8', 5.0, 525, 'ZF 8HP', 'AWD', 'Petrol', 'SUV', 'UK');

-- Ошибки OBD2 (30 штук)
INSERT INTO errors (code, title, description, symptoms, causes, solutions, severity, repair_complexity, estimated_cost_rub, category_id) VALUES
('P0100', 'Неисправность MAF', 'Сигнал MAF вне диапазона', 'Плавающие обороты', 'Загрязнение датчика', 'Очистка/замена MAF', 'medium', 'easy', 3500, 1),
('P0115', 'Неисправность ECT', 'Датчик температуры ОЖ', 'Плохой прогрев', 'Неисправен датчик', 'Замена ECT', 'medium', 'easy', 2000, 1),
('P0120', 'Неисправность TPS', 'Датчик положения дросселя', 'Провалы при разгоне', 'Износ TPS', 'Замена TPS', 'medium', 'easy', 3000, 1),
('P0128', 'Термостат', 'Двигатель не прогревается', 'Повышенный расход', 'Неисправен термостат', 'Замена термостата', 'medium', 'medium', 5000, 1),
('P0130', 'Лямбда-зонд Bank 1', 'O2 датчик не работает', 'Повышенный расход', 'Износ датчика', 'Замена лямбда-зонда', 'medium', 'medium', 6000, 6),
('P0171', 'Бедная смесь Bank 1', 'Система не может компенсировать', 'Потеря мощности', 'Подсос воздуха', 'Поиск подсоса', 'high', 'hard', 12000, 1),
('P0172', 'Богатая смесь Bank 1', 'Система не может компенсировать', 'Черный дым', 'Негерметичность форсунок', 'Диагностика форсунок', 'high', 'hard', 15000, 1),
('P0300', 'Пропуски зажигания', 'Множественные цилиндры', 'Троение, вибрация', 'Свечи, катушки', 'Замена свечей', 'high', 'medium', 8000, 1),
('P0301', 'Пропуски цилиндр 1', 'Пропуски в 1-м цилиндре', 'Троение', 'Свеча/катушка цилиндра 1', 'Замена свечи', 'medium', 'medium', 5000, 1),
('P0302', 'Пропуски цилиндр 2', 'Пропуски во 2-м цилиндре', 'Троение', 'Свеча/катушка цилиндра 2', 'Замена свечи', 'medium', 'medium', 5000, 1),
('P0325', 'Датчик детонации', 'Нет сигнала от датчика', 'Снижение мощности', 'Неисправен датчик', 'Замена датчика', 'medium', 'easy', 3500, 1),
('P0335', 'Датчик коленвала', 'Нет сигнала CKP', 'Двигатель не заводится', 'Неисправен CKP', 'Замена датчика', 'high', 'medium', 6000, 1),
('P0340', 'Датчик распредвала', 'Нет сигнала CMP', 'Затрудненный пуск', 'Неисправен CMP', 'Замена датчика', 'medium', 'medium', 5500, 1),
('P0400', 'Система EGR', 'Поток EGR не соответствует', 'Детонация', 'Засорение клапана', 'Чистка/замена EGR', 'medium', 'medium', 8000, 6),
('P0420', 'Катализатор Bank 1', 'Низкая эффективность', 'Повышенный выброс', 'Износ катализатора', 'Замена катализатора', 'high', 'hard', 45000, 6),
('P0440', 'Система EVAP', 'Утечка паров топлива', 'Запах бензина', 'Неплотная крышка', 'Проверка крышки', 'medium', 'medium', 6000, 6),
('P0446', 'Вентиляция EVAP', 'Не работает клапан', 'Вакуум в баке', 'Засорение клапана', 'Замена клапана', 'medium', 'easy', 4500, 6),
('P0500', 'Датчик скорости', 'Нет сигнала VSS', 'Не работает спидометр', 'Неисправен VSS', 'Замена датчика', 'medium', 'medium', 5000, 3),
('P0505', 'Система холостого хода', 'Не стабилизируются обороты', 'Плавающие обороты', 'Засорение РХХ', 'Чистка/замена РХХ', 'medium', 'easy', 4000, 1),
('P0560', 'Напряжение бортовой сети', 'Низкое напряжение', 'Различные сбои', 'Неисправен генератор', 'Диагностика генератора', 'medium', 'medium', 8000, 3),
('P0600', 'Связь с модулями', 'Потеря связи между ЭБУ', 'Различные симптомы', 'Проблемы CAN-шины', 'Диагностика CAN', 'high', 'hard', 20000, 3),
('P0700', 'Управление КПП', 'Сигнал от TCM', 'Аварийный режим КПП', 'Неисправность TCM', 'Диагностика TCM', 'high', 'hard', 30000, 2),
('P0715', 'Датчик оборотов КПП', 'Нет сигнала ISS', 'Рывки переключения', 'Неисправен ISS', 'Замена датчика', 'high', 'medium', 12000, 2),
('P0740', 'Муфта гидротрансформатора', 'TCC не работает', 'Повышенный расход', 'Неисправна муфта', 'Ремонт ГДТ', 'high', 'hard', 60000, 2),
('C0035', 'ABS левого переднего', 'Нет сигнала датчика', 'Не работает ABS', 'Неисправен датчик', 'Замена датчика', 'high', 'medium', 8000, 4),
('B0001', 'Подушка безопасности', 'Ошибка цепи подушки', 'Горит лампа Airbag', 'Обрыв шлейфа', 'Замена шлейфа', 'high', 'hard', 25000, 8),
('B2799', 'Иммобилайзер', 'ЭБУ не видит чип', 'Двигатель не заводится', 'Неисправен чип', 'Программирование ключа', 'high', 'hard', 15000, 8),
('P1300', 'Пропуски зажигания (VAG)', 'Производитель-специфично', 'Троение', 'Аналогично P0300', 'Диагностика зажигания', 'medium', 'medium', 6000, 1),
('P2187', 'Бедная смесь на ХХ', 'Коррекция на ХХ', 'Нестабильный ХХ', 'Подсос воздуха', 'Поиск подсоса', 'medium', 'medium', 8000, 1),
('U0100', 'Потеря связи с ECM', 'CAN: нет связи с ЭБУ', 'Двигатель не заводится', 'Проблема CAN', 'Диагностика CAN', 'high', 'hard', 25000, 3);

-- Связи машина-ошибка
INSERT INTO car_errors (car_id, error_id, frequency, specific_notes) VALUES
(1, 1, 70, 'Часто на Audi A4'),
(1, 8, 60, 'Пропуски зажигания'),
(2, 1, 65, 'Часто на BMW 3'),
(2, 15, 50, 'Катализатор'),
(3, 1, 75, 'Часто на Mercedes'),
(4, 8, 80, 'Очень часто на Camry'),
(4, 16, 55, 'EVAP система'),
(5, 8, 70, 'Гибридная система'),
(6, 1, 60, 'Honda CR-V'),
(7, 1, 65, 'Kia Sportage'),
(8, 1, 70, 'Hyundai Tucson'),
(9, 1, 55, 'Ford Focus'),
(10, 1, 60, 'VW Tiguan'),
(11, 8, 65, 'Nissan X-Trail'),
(12, 1, 60, 'Mazda CX-5'),
(13, 8, 50, 'Lada Vesta'),
(14, 1, 55, 'Volvo XC60'),
(15, 8, 60, 'Subaru Forester'),
(16, 1, 65, 'Geely Atlas'),
(17, 1, 70, 'Haval F7'),
(18, 1, 60, 'Peugeot 3008'),
(19, 1, 55, 'Renault Duster'),
(20, 1, 75, 'Range Rover');

-- Тестовые пользователи
INSERT INTO users (email, username, phone, device_type) VALUES
('demo@caranalytics.ru', 'demo_user', '+79991234567', 'mobile'),
('admin@caranalytics.ru', 'admin', '+79990000000', 'web'),
('service@caranalytics.ru', 'service_manager', '+79991112233', 'web');

-- ============================================
-- 10. ПРОВЕРКА
-- ============================================
DO $$
DECLARE
    v_tables INTEGER;
    v_views INTEGER;
    v_functions INTEGER;
    v_triggers INTEGER;
    v_procedures INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_tables FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    SELECT COUNT(*) INTO v_views FROM information_schema.views WHERE table_schema = 'public';
    SELECT COUNT(*) INTO v_functions FROM information_schema.routines WHERE routine_schema = 'public' AND routine_type = 'FUNCTION';
    SELECT COUNT(*) INTO v_triggers FROM information_schema.triggers WHERE trigger_schema = 'public';
    SELECT COUNT(*) INTO v_procedures FROM information_schema.routines WHERE routine_schema = 'public' AND routine_type = 'PROCEDURE';
    
    RAISE NOTICE '✅ БД успешно создана:';
    RAISE NOTICE '   📊 Таблиц: %', v_tables;
    RAISE NOTICE '   👁️ Представлений: %', v_views;
    RAISE NOTICE '   🔧 Функций: %', v_functions;
    RAISE NOTICE '   ⚡ Триггеров: %', v_triggers;
    RAISE NOTICE '   📦 Процедур: %', v_procedures;
END $$;