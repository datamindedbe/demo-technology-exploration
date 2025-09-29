{{ config(materialized='view') }}

with source_data as (
    select * from {{ source('employee_db', 'department_employee') }}
),

renamed as (
    select
        employee_id,
        department_id,
        from_date as assignment_start_date,
        to_date as assignment_end_date,
        -- Flag for current assignment
        case 
            when to_date = '9999-01-01' then true 
            else false 
        end as is_current_assignment,
        -- Calculate assignment duration in days
        case 
            when to_date = '9999-01-01' then 
                current_date - from_date
            else 
                to_date - from_date
        end as assignment_duration_days
    from source_data
)

select * from renamed
