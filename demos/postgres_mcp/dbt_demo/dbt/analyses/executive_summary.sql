-- Executive Summary Analysis
-- This analysis demonstrates key insights from the employee analytics models

with company_overview as (
    select 
        count(*) as total_employees,
        count(distinct current_department_name) as total_departments,
        round(avg(current_salary), 2) as avg_salary,
        round(avg(years_of_service), 1) as avg_tenure_years
    from {{ ref('employee_summary') }}
),

salary_distribution as (
    select 
        salary_range,
        count(*) as employee_count,
        round((count(*)::float / (select count(*) from {{ ref('employee_summary') }})) * 100, 1) as percentage
    from {{ ref('salary_analytics') }}
    group by salary_range
    order by 
        case salary_range
            when 'Under $50k' then 1
            when '$50k-$75k' then 2
            when '$75k-$100k' then 3
            when '$100k-$125k' then 4
            when '$125k-$150k' then 5
            when 'Over $150k' then 6
        end
),

department_summary as (
    select 
        current_department_name,
        total_employees,
        avg_salary,
        male_percentage,
        female_percentage,
        veteran_percentage
    from {{ ref('department_analytics') }}
    order by total_employees desc
    limit 5
),

turnover_risk_summary as (
    select 
        turnover_risk,
        count(*) as employee_count,
        round((count(*)::float / (select count(*) from {{ ref('employee_turnover_analysis') }})) * 100, 1) as percentage
    from {{ ref('employee_turnover_analysis') }}
    group by turnover_risk
    order by 
        case turnover_risk
            when 'High Risk - No Promotions' then 1
            when 'High Risk - Job Hopper' then 2
            when 'Medium Risk - Limited Growth' then 3
            when 'Medium Risk - Low Growth' then 4
            when 'Low Risk' then 5
        end
)

select 
    'Company Overview' as section,
    null as metric_name,
    total_employees::text as metric_value,
    null as additional_info
from company_overview

union all

select 
    'Company Overview' as section,
    'Total Departments' as metric_name,
    total_departments::text as metric_value,
    null as additional_info
from company_overview

union all

select 
    'Company Overview' as section,
    'Average Salary' as metric_name,
    '$' || avg_salary::text as metric_value,
    null as additional_info
from company_overview

union all

select 
    'Company Overview' as section,
    'Average Tenure' as metric_name,
    avg_tenure_years::text || ' years' as metric_value,
    null as additional_info
from company_overview

union all

select 
    'Salary Distribution' as section,
    salary_range as metric_name,
    employee_count::text as metric_value,
    percentage::text || '%' as additional_info
from salary_distribution

union all

select 
    'Top Departments' as section,
    current_department_name as metric_name,
    total_employees::text as metric_value,
    'Avg: $' || avg_salary::text || ', Veterans: ' || veteran_percentage::text || '%' as additional_info
from department_summary

union all

select 
    'Turnover Risk' as section,
    turnover_risk as metric_name,
    employee_count::text as metric_value,
    percentage::text || '%' as additional_info
from turnover_risk_summary

order by section, metric_name
