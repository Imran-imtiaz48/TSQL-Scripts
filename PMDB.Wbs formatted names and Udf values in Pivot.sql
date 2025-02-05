/*-----------------------------------------------------------------------+
| Purpose:	User-defined fields formatted values
| Note:		Optimized SQL Script
+------------------------------------------------------------------------*/

:setvar _server "Server1"
:setvar _user "***username***"
:setvar _password "***password***"
:setvar _database "PMDB_1"
:connect $(_server) -U $(_user) -P $(_password)

USE [$(_database)];
GO

WITH project_filter AS (
    SELECT '12345' AS proj_id
),
wbs_relate AS (
    SELECT 
        pwbs.wbs_id,
        pwbs.parent_wbs_id,
        pwbs.proj_id,
        CAST(pwbs.wbs_short_name AS NVARCHAR(MAX)) AS wbs_format_name,
        pwbs.wbs_short_name,
        pwbs.wbs_name,
        0 AS wbs_level_nbr
    FROM PROJWBS pwbs
    JOIN project_filter pf ON pwbs.proj_id = pf.proj_id
    WHERE pwbs.proj_node_flag = 'Y' -- Parent record

    UNION ALL

    SELECT 
        pwbs.wbs_id,
        pwbs.parent_wbs_id,
        pwbs.proj_id,
        rwbs.wbs_format_name + '.' + pwbs.wbs_short_name,
        pwbs.wbs_short_name,
        pwbs.wbs_name,
        rwbs.wbs_level_nbr + 1
    FROM PROJWBS pwbs
    JOIN wbs_relate rwbs ON pwbs.parent_wbs_id = rwbs.wbs_id
    JOIN project_filter pf ON pwbs.proj_id = pf.proj_id  
    WHERE pwbs.proj_node_flag = 'N'  -- Child record
),
udf_values_case AS (
    SELECT 
        uv.proj_id,
        ut.udf_type_label,
        CASE 
            WHEN ut.logical_data_type IN ('FT_TEXT','FT_STATICTYPE') THEN uv.udf_text 
            WHEN ut.logical_data_type IN ('FT_START_DATE','FT_END_DATE') THEN FORMAT(uv.udf_date, 'dd-MMM-yyyy')
            WHEN ut.logical_data_type IN ('FT_FLOAT_2_DECIMALS','FT_INT', 'FT_MONEY') THEN CAST(uv.udf_number AS NVARCHAR)
            ELSE '### The - ' + ut.logical_data_type + ' is NOT coded for. ###' 
        END AS udf_value
    FROM UDFTYPE ut
    JOIN UDFVALUE uv ON ut.udf_type_id = uv.udf_type_id
    JOIN project_filter pf ON uv.proj_id = pf.proj_id
),
activity_code_pivot AS (
    SELECT 
        proj_id,
        task_id,
        [Region],
        [Discipline],
        [Asset Lead],
        [Responsible Engineer],
        [Priority]
    FROM (
        SELECT 
            ta.proj_id,
            ta.task_id,
            ac.short_name,
            at.actv_code_type
        FROM TASKACTV ta
        LEFT JOIN ACTVTYPE at ON at.actv_code_type_id = ta.actv_code_type_id
        LEFT JOIN ACTVCODE ac ON at.actv_code_type_id = ac.actv_code_type_id
        JOIN project_filter pf ON ta.proj_id = pf.proj_id
        WHERE at.actv_code_type IN ('Region', 'Discipline', 'Asset Lead', 'Responsible Engineer', 'Priority')
    ) pL
    PIVOT (
        MAX(short_name) FOR actv_code_type IN (
            [Region], [Discipline], [Asset Lead], [Responsible Engineer], [Priority]
        )
    ) AS pvt
),
udf_values_pivot AS (
    SELECT 
        proj_id,
        task_id,
        [Indicative Cost],
        [Control Budget],	  
        [Actual Cost],
        [Asset Location],
        [Focal Point],
        [Onsite Tech Support],
        [Specific Discipline]
    FROM (
        SELECT
            pj.proj_id,
            tk.task_id,
            uv.udf_type_label,
            uv.udf_value
        FROM udf_values_case uv
        JOIN PROJECT pj ON pj.proj_id = uv.proj_id
        JOIN TASK tk ON pj.proj_id = tk.proj_id
        JOIN project_filter pf ON uv.proj_id = pf.proj_id
        WHERE tk.task_type IN ('tt_mile', 'tt_finmile')
    ) pL
    PIVOT (
        MAX(udf_value) FOR udf_type_label IN (
            [Indicative Cost], [Control Budget], [Actual Cost], [Asset Location],
            [Focal Point], [Onsite Tech Support], [Specific Discipline]
        )
    ) AS pvt
)
SELECT
    ac.[Region],
    ac.[Discipline],
    ac.[Asset Lead],
    udf.[Indicative Cost],
    tk.task_code AS [Activity ID],
    tk.task_name AS [Activity Name],
    tk.phys_complete_pct AS [Activity % Complete],
    tk.act_start_date AS [Actual Start],
    tk.act_end_date AS [Actual Finish],
    tk.early_start_date AS [Start],
    tk.early_end_date AS [Finish],
    udf.[Control Budget],
    udf.[Actual Cost],
    wbs.wbs_name AS [WBS Name],
    wbs.wbs_format_name AS [WBS Path],
    udf.[Asset Location],
    udf.[Focal Point],
    udf.[Onsite Tech Support],
    udf.[Specific Discipline],
    ac.[Responsible Engineer],
    ac.[Priority]
FROM wbs_relate wbs
JOIN TASK tk ON tk.wbs_id = wbs.wbs_id AND tk.proj_id = wbs.proj_id
JOIN udf_values_pivot udf ON udf.proj_id = tk.proj_id AND udf.task_id = tk.task_id
LEFT JOIN activity_code_pivot ac ON ac.task_id = tk.task_id;

GO
