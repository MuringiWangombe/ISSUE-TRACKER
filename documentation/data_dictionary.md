# 📖 Data Dictionary: IT Support Issue Tracker

## 📌 Overview
This document details the metadata, data types, and source logic for the `anonymized_portfolio_data.xlsx` dataset used in the Power BI dashboard. It specifically highlights the calculated metrics derived from SQL and the anonymization techniques applied via Python.

---

## 🛡️ 1. Anonymized & Categorical Dimensions
*Columns modified to protect PII (Personally Identifiable Information) or generalize business entities.*

| Column Name | Data Type | Definition | Anonymization Method |
| :--- | :--- | :--- | :--- |
| **School Name** | Text | The client entity reporting the issue. | **Tokenization** (e.g., *School 1, School 2*) |
| **Regional Manager Name** | Text | The staff member responsible for the client region. | **Tokenization** (e.g., *Regional Manager 1*) |
| **Relationship Manager Name**| Text | The primary point of contact for the client. | **Tokenization** (e.g., *Relationship Manager 1*) |
| **Resolved By Name** | Text | The specific support agent who resolved the ticket. | **Tokenization** (e.g., *Agent 1, Agent 2*) |
| **product** | Text | The software platform associated with the ticket. | **Generalized Substitution** (e.g., *Financial Management Suite*) |
| **Region / Country** | Text | Geographic grouping of the client. | **Tokenization** (e.g., *Region 1, Country 1*) |
| **Issue Title** | Text | The subject line of the support ticket. | **Redacted/Generalized** (*Generic Issue Description*) |

---

## ⏱️ 2. Calculated Time Metrics (SQL Derived)
*Key Performance Indicators (KPIs) calculated using DATEDIFF and Window Functions in SQL.*

| Column Name | Data Type | Calculation Logic | Business Definition |
| :--- | :--- | :--- | :--- |
| **frt_seconds** | Integer | `DATEDIFF(SECOND, created_at, first_response)` | **First Response Time:** Time elapsed between when a ticket is assigned to an agent and the first agent reply. Used to measure initial responsiveness. |
| **time_in_tier_seconds** | Integer | `LEAD()` Window Function Calculation | **Escalation Lag:** The duration a ticket remained in a specific support tier (e.g., Tier 1) before moving to the next stage or being resolved. |
| **resolution_time_seconds** | Integer | `DATEDIFF(SECOND, created_at, resolution_time)` | **Total Resolution Time:** The total lifecycle duration of the ticket from opening to the fix being applied. |
| **closing_time_seconds** | Integer | `DATEDIFF(SECOND, created_at, closing_time)` | **Closing Time:** Duration until the ticket was formally closed (includes post-resolution verification). |

---

## 🚦 3. SLA Flags & Status
*Binary flags and status indicators used for compliance reporting.*

| Column Name | Data Type | Values | Definition |
| :--- | :--- | :--- | :--- |
| **frt_breached** | Binary | `0` (Met), `1` (Breached) | Indicates if the First Response Time exceeded the SLA threshold (1 hour for High Priority, 24 hours for Low). |
| **tier_sla_breached** | Binary | `0` (Met), `1` (Breached) | Indicates if the ticket stayed in a specific tier longer than allowed before escalation/resolution. |
| **priority_level** | Text | `HIGH`, `MEDIUM`, `LOW` | Assigned based on `Issue Type`. *Bug/Critical* = HIGH; *Feature Request* = MEDIUM. |
| **escalation_level** | Text | `Tier 1`, `Tier 2`, `Tier 3` | The current or final support level required to solve the issue. |
| **issue_status** | Text | `OPEN`, `CLOSED`, `PENDING` | The current state of the ticket workflow. |

---

## 📅 4. Timestamps
*Original temporal data used for drill-down analysis.*

| Column Name | Format | Definition |
| :--- | :--- | :--- |
| **Ticket Creation Date** | DD/MM/YYYY HH:MM:SS | The exact timestamp when the client submitted the issue. |
| **event_timestamp** | DD/MM/YYYY HH:MM:SS | The timestamp of the specific action (status change, escalation) being recorded in the row. |