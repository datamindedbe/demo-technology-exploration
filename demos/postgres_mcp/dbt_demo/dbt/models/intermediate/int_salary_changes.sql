{{ config(materialized='view') }}

with salary_history as (
    select * from {{ ref('stg_salaries') }}
),

salary_changes as (
    select 
        employee_id,
        salary_amount,
        salary_start_date,
        salary_end_date,
        is_current_salary,
        salary_duration_days,
        
        -- Calculate previous salary for comparison
        lag(salary_amount) over (
            partition by employee_id 
            order by salary_start_date
        ) as previous_salary,
        
        -- Calculate salary change amount and percentage
        salary_amount - lag(salary_amount) over (
            partition by employee_id 
            order by salary_start_date
        ) as salary_change_amount,
        
        case 
            when lag(salary_amount) over (
                partition by employee_id 
                order by salary_start_date
            ) > 0 then
                round(
                    ((salary_amount - lag(salary_amount) over (
                        partition by employee_id 
                        order by salary_start_date
                    )) / lag(salary_amount) over (
                        partition by employee_id 
                        order by salary_start_date
                    )) * 100, 2
                )
            else null
        end as salary_change_percentage,
        
        -- Rank salary changes for each employee
        row_number() over (
            partition by employee_id 
            order by salary_start_date
        ) as salary_change_rank
        
    from salary_history
)

select * from salary_changes
