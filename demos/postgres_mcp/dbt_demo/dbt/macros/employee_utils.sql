-- Macro to calculate age from birth date
{% macro calculate_age(birth_date_column) %}
    date_part('year', age(current_date, {{ birth_date_column }}))
{% endmacro %}

-- Macro to calculate years of service
{% macro calculate_years_of_service(hire_date_column) %}
    date_part('year', age(current_date, {{ hire_date_column }}))
{% endmacro %}

-- Macro to check if date is current (9999-01-01)
{% macro is_current_date(date_column) %}
    case when {{ date_column }} = '9999-01-01' then true else false end
{% endmacro %}

-- Macro to get current records only
{% macro get_current_records(table_name, date_column) %}
    select * from {{ ref(table_name) }}
    where {{ date_column }} = '9999-01-01'
{% endmacro %}

-- Macro to calculate salary percentile within a group
{% macro calculate_salary_percentile(salary_column, partition_columns) %}
    percent_rank() over (
        partition by {{ partition_columns }}
        order by {{ salary_column }}
    ) * 100
{% endmacro %}

-- Macro to categorize salary ranges
{% macro categorize_salary(salary_column) %}
    case 
        when {{ salary_column }} < 50000 then 'Under $50k'
        when {{ salary_column }} < 75000 then '$50k-$75k'
        when {{ salary_column }} < 100000 then '$75k-$100k'
        when {{ salary_column }} < 125000 then '$100k-$125k'
        when {{ salary_column }} < 150000 then '$125k-$150k'
        else 'Over $150k'
    end
{% endmacro %}

-- Macro to categorize tenure
{% macro categorize_tenure(years_of_service_column) %}
    case 
        when {{ years_of_service_column }} < 2 then 'New (0-2 years)'
        when {{ years_of_service_column }} between 2 and 5 then 'Junior (2-5 years)'
        when {{ years_of_service_column }} between 5 and 10 then 'Mid-level (5-10 years)'
        when {{ years_of_service_column }} between 10 and 20 then 'Senior (10-20 years)'
        else 'Veteran (20+ years)'
    end
{% endmacro %}
