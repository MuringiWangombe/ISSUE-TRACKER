WITH base AS (
    SELECT
        it.issue_tracker,
        it.escalation_level,
        it.status,
        it.event_timestamp,
        it.first_response_timestamp,
        it.resolution_timestamp
    FROM [zft].[issue_timeline] it
),

calc AS (
    SELECT
        b.issue_tracker,
        b.escalation_level,
        b.status,
        b.event_timestamp,
        b.first_response_timestamp,
        b.resolution_timestamp,
        nip.event_timestamp AS next_in_progress_ts,
        nip.resolution_timestamp AS next_resolution_ts,

        /* ✅ First Response Time (FRT): from OPEN/ESCALATED/ON_STANDBY/TRIAGE → next IN_PROGRESS */
        CASE 
            WHEN b.status IN ('OPEN','ESCALATED','ON_STANDBY','TRIAGE')
            THEN DATEDIFF(SECOND, b.event_timestamp, nip.event_timestamp)
        END AS frt_seconds,

        /* ✅ Time in Tier: from current (OPEN/ESCALATED/ON_STANDBY/TRIAGE) → next IN_PROGRESS resolution */
        CASE 
            WHEN b.status IN ('OPEN','ESCALATED','ON_STANDBY','TRIAGE')
            THEN DATEDIFF(SECOND, b.event_timestamp, nip.resolution_timestamp)
        END AS time_in_tier_seconds

    FROM base b
    OUTER APPLY (
        SELECT TOP (1)
            t2.event_timestamp,
            t2.resolution_timestamp
        FROM [zft].[issue_timeline] t2
        WHERE 
            t2.issue_tracker = b.issue_tracker
            AND t2.escalation_level = b.escalation_level
            AND t2.status = 'IN_PROGRESS'
            AND t2.event_timestamp >= b.event_timestamp
        ORDER BY t2.event_timestamp
    ) AS nip
),

/* 🕒 New CTE: Calculate Resolution and Closing Times */
ticket_times AS (
    SELECT
        issue_tracker,
        MIN(CASE WHEN status = 'OPEN' THEN event_timestamp END) AS open_time,
        MAX(CASE WHEN status = 'RESOLVED' THEN event_timestamp END) AS resolved_time,
        MAX(CASE WHEN status = 'CLOSED' THEN event_timestamp END) AS closed_time
    FROM [zft].[issue_timeline]
    GROUP BY issue_tracker
),

sla_clean AS (
    SELECT
        id,
        priority_level,
        max_duration,
        CASE 
            WHEN max_duration = 'THIRTY_MINUTES' THEN 1800
            WHEN max_duration = 'ONE_HOUR' THEN 3600
            WHEN max_duration = 'FOUR_HOURS' THEN 14400
            WHEN max_duration = 'ONE_DAY' THEN 86400
            WHEN max_duration = 'THREE_DAYS' THEN 259200
            WHEN max_duration = 'ONE_WEEK' THEN 604800
            ELSE NULL
        END AS sla_seconds
    FROM  zft.service_level_agreement
    -- WHERE deleted = 0   -- exclude deleted SLA rows
),


/* 🧠 Combine per-row metrics with per-ticket resolution & closing times */
combined AS (
    SELECT
        c.issue_tracker,
        c.escalation_level,
        c.status,
        c.event_timestamp,
        c.first_response_timestamp,
        c.resolution_timestamp,
        c.frt_seconds,
        c.time_in_tier_seconds,
        t.open_time,
        t.resolved_time,
        t.closed_time,

        /* Resolution Time = RESOLVED - OPEN */
        DATEDIFF(SECOND, t.open_time, t.resolved_time) AS resolution_time_seconds,

        /* Closing Time = CLOSED - RESOLVED */
        DATEDIFF(SECOND, t.resolved_time, t.closed_time) AS closing_time_seconds,

        /* Identify final row per ticket for cleaner Power BI display */
        CASE 
            WHEN c.event_timestamp = (
                SELECT MAX(x.event_timestamp)
                FROM [zft].[issue_timeline] x
                WHERE x.issue_tracker = c.issue_tracker
            ) THEN 1 ELSE 0
        END AS is_final_row,
                /* 🧩 Work Duration = time spent actively working on issue */
        CASE 
            WHEN c.status = 'IN_PROGRESS' 
                 AND c.resolution_timestamp IS NOT NULL 
            THEN DATEDIFF(SECOND, c.event_timestamp, c.resolution_timestamp)
        END AS work_duration_seconds

    FROM calc c
    LEFT JOIN ticket_times t 
        ON c.issue_tracker = t.issue_tracker
)

/* 🎯 Final Output */
SELECT
    cbd.issue_tracker,
    COALESCE(cbd.escalation_level, 'UNGROUPED') AS escalation_level,
    cbd.status AS timeline_status,
    cbd.event_timestamp,
    cbd.first_response_timestamp,
    cbd.resolution_timestamp,
    cbd.work_duration_seconds,
    cbd.frt_seconds,
    cbd.time_in_tier_seconds,
    CASE WHEN cbd.is_final_row = 1 THEN cbd.resolution_time_seconds END AS resolution_time_seconds,
    CASE WHEN cbd.is_final_row = 1 THEN cbd.closing_time_seconds END AS closing_time_seconds,
    it_main.issue_category,
    it_main.product,
    it_main.status AS issue_status,
    it_main.sub_module AS [Sub Module],
    it_main.title AS [Issue Title],
    it_main.issue_type AS [Issue Type],
    s.school_name AS [School Name],
    s.region_name AS [Region],
    s.country_name AS [Country],
    s.country_name AS [County],
    CONCAT_WS(' ', rmm.first_name, rmm.last_name, rmm.sur_name) AS [Regional Manager Name],
    CONCAT_WS(' ', rm.first_name, rm.last_name, rm.sur_name) AS [Relationship Manager Name],
    t.assigned_by,
    t.assigned_to,
    t.resolved_by,
    CONCAT_WS(' ', u.first_name, u.last_name, u.sur_name) AS [Resolved By Name],
    cs.type AS [Customer Support Type],
    cs.availability_status AS [Agent Availability],
    sc.priority_level,
    CASE WHEN cbd.frt_seconds > sc.sla_seconds THEN 1 ELSE 0 END AS frt_breached,
    CASE WHEN cbd.time_in_tier_seconds > sc.sla_seconds THEN 1 ELSE 0 END AS tier_sla_breached
    

FROM combined cbd

-- Link issue master data
LEFT JOIN zft.issue_tracker it_main 
    ON it_main.id = cbd.issue_tracker

-- Link SLA definitions
LEFT JOIN sla_clean sc 
    ON sc.id = it_main.sla

-- ✅ Rejoin issue_timeline to bring in event-level context
LEFT JOIN zft.issue_timeline t 
    ON t.issue_tracker = cbd.issue_tracker
    AND t.event_timestamp = cbd.event_timestamp

-- Bring in assigned_by, assigned_to, resolved_by from timeline
LEFT JOIN zft.customer_support_agents cs 
    ON cs.id = t.assigned_to OR cs.id = t.resolved_by

-- Agent user details
LEFT JOIN zfi.users u 
    ON u.id = cs.agent

-- School that raised the issue
LEFT JOIN zfi.schools s 
    ON it_main.school = s.id

-- Relationship Manager
LEFT JOIN zfi.users rm 
    ON rm.id = s.relationship_manager

-- Regional Manager
LEFT JOIN zfi.users rmm 
    ON rmm.id = s.regional_manager

-- Issue Creator
LEFT JOIN zfi.users cr 
    ON cr.id = it_main.created_by_id

ORDER BY cbd.issue_tracker, cbd.event_timestamp;

