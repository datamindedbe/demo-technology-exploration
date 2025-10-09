{{ config(materialized='table') }}

with salary_changes as (
    select * from {{ ref('int_salary_changes') }}
),

employee_summary as (
    select * from {{ ref('employee_summary') }}
),

turnover_indicators as (
    select 
        es.employee_id,
        es.full_name,
        es.current_department_name,
        es.current_department_category,
        es.gender,
        es.years_of_service,
        es.tenure_category,
        es.current_salary,
        es.total_salary_changes,
        es.total_salary_increase,
        es.salary_growth_percentage,
        
        -- Calculate time since last salary change
        case 
            when sc.salary_start_date is not null then
                current_date - sc.salary_start_date
            else null
        end as days_since_last_salary_change,
        
        -- Calculate years since last salary change
        case 
            when sc.salary_start_date is not null then
                round((current_date - sc.salary_start_date) / 365.25, 1)
            else null
        end as years_since_last_salary_change,
        
        -- Risk indicators
        case 
            when es.years_of_service > 5 and es.total_salary_changes = 0 then 'High Risk - No Promotions'
            when es.years_of_service > 3 and es.total_salary_changes <= 1 then 'Medium Risk - Limited Growth'
            when es.salary_growth_percentage < 10 and es.years_of_service > 5 then 'Medium Risk - Low Growth'
            when es.years_of_service < 2 and es.total_salary_changes > 2 then 'High Risk - Job Hopper'
            else 'Low Risk'
        end as turnover_risk,
        
        -- Career progression score
        case 
            when es.total_salary_changes = 0 then 0
            when es.total_salary_changes = 1 then 1
            when es.total_salary_changes between 2 and 3 then 2
            when es.total_salary_changes between 4 and 6 then 3
            else 4
        end as career_progression_score,
        
        -- Salary growth rate per year
        case 
            when es.years_of_service > 0 then
                round((es.salary_growth_percentage / es.years_of_service)::numeric, 2)
            else 0
        end as annual_salary_growth_rate
        
    from employee_summary es
    left join (
        select 
            employee_id,
            salary_start_date,
            row_number() over (partition by employee_id order by salary_start_date desc) as rn
        from salary_changes
        where is_current_salary = true
    ) sc on es.employee_id = sc.employee_id and sc.rn = 1
)

select 
    employee_id,
    full_name,
    current_department_name,
    current_department_category,
    gender,
    years_of_service,
    tenure_category,
    current_salary,
    total_salary_changes,
    total_salary_increase,
    salary_growth_percentage,
    days_since_last_salary_change,
    years_since_last_salary_change,
    turnover_risk,
    career_progression_score,
    annual_salary_growth_rate,
    
    -- Recommendations
    case 
        when turnover_risk = 'High Risk - No Promotions' then 'Consider promotion or salary increase'
        when turnover_risk = 'High Risk - Job Hopper' then 'Monitor closely, may need retention strategy'
        when turnover_risk = 'Medium Risk - Limited Growth' then 'Review career development opportunities'
        when turnover_risk = 'Medium Risk - Low Growth' then 'Consider performance review and growth plan'
        else 'Continue current development path'
    end as recommendation

from turnover_indicators
order by 
    case turnover_risk
        when 'High Risk - No Promotions' then 1
        when 'High Risk - Job Hopper' then 2
        when 'Medium Risk - Limited Growth' then 3
        when 'Medium Risk - Low Growth' then 4
        else 5
    end,
    years_of_service desc
