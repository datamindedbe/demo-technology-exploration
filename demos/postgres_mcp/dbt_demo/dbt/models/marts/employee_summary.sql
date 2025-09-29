{{ config(materialized='table') }}

with current_state as (
    select * from {{ ref('int_employee_current_state') }}
),

salary_stats as (
    select 
        employee_id,
        count(*) as total_salary_changes,
        min(salary_amount) as min_salary,
        max(salary_amount) as max_salary,
        avg(salary_amount) as avg_salary,
        sum(salary_change_amount) as total_salary_increase
    from {{ ref('int_salary_changes') }}
    where salary_change_amount is not null
    group by employee_id
)

select 
    cs.employee_id,
    cs.full_name,
    cs.gender,
    cs.hire_date,
    cs.years_of_service,
    cs.current_salary,
    cs.current_department_name,
    cs.current_department_category,
    cs.current_job_title,
    cs.current_title_level,
    
    -- Salary statistics
    coalesce(ss.total_salary_changes, 0) as total_salary_changes,
    coalesce(ss.min_salary, cs.current_salary) as min_salary,
    coalesce(ss.max_salary, cs.current_salary) as max_salary,
    coalesce(ss.avg_salary, cs.current_salary) as avg_salary,
    coalesce(ss.total_salary_increase, 0) as total_salary_increase,
    
    -- Calculate salary growth rate
    case 
        when ss.min_salary > 0 and ss.max_salary > ss.min_salary then
            round(((ss.max_salary - ss.min_salary) / ss.min_salary) * 100, 2)
        else 0
    end as salary_growth_percentage,
    
    -- Employee experience level for promotions and salary bands
    case 
        when cs.years_of_service >= 10 then 'Senior'
        when cs.years_of_service >= 5 then 'Mid-level'
        when cs.years_of_service >= 2 then 'Junior'
        when cs.years_of_service >= 1 then 'Trainee'
        else 'New Hire'
    end as experience_level,
    
    -- Employee tenure categories (separate from experience level)
    case 
        when cs.years_of_service < 2 then 'New (0-2 years)'
        when cs.years_of_service between 2 and 5 then 'Junior (2-5 years)'
        when cs.years_of_service between 5 and 10 then 'Mid-level (5-10 years)'
        when cs.years_of_service between 10 and 20 then 'Senior (10-20 years)'
        else 'Veteran (20+ years)'
    end as tenure_category,
    
    -- Salary percentile (will be calculated in a separate model)
    null as salary_percentile

from current_state cs
left join salary_stats ss on cs.employee_id = ss.employee_id
