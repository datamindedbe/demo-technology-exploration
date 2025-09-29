{{ config(materialized='view') }}

with source_data as (
    select * from {{ source('employee_db', 'employee') }}
),

renamed as (
    select
        id as employee_id,
        first_name,
        last_name,
        birth_date,
        gender,
        hire_date,
        -- Calculate age at hire
        date_part('year', age(hire_date, birth_date)) as age_at_hire,
        -- Calculate years of service (as of current date)
        date_part('year', age(current_date, hire_date)) as years_of_service,
        -- Create full name
        concat(first_name, ' ', last_name) as full_name
    from source_data
)

select * from renamed
