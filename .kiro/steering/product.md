# Product Overview

AI-Assisted SRE Incident Analysis System - an event-driven AWS pipeline that automatically detects infrastructure issues, collects contextual data, and generates root-cause hypotheses using LLM reasoning.

## Purpose

Portfolio/interview project demonstrating production-grade incident management architecture. The system is advisory-only (no auto-remediation) and showcases:

- Event-driven serverless architecture on AWS
- Parallel data collection and correlation
- LLM-powered incident analysis using Amazon Bedrock
- Security-first design with least-privilege IAM
- Graceful degradation and observability patterns

## Key Capabilities

- Automatic incident detection via CloudWatch Alarms
- Parallel collection of metrics, logs, and deployment context
- AI-generated root-cause hypotheses with confidence levels
- Human notification via Slack and email
- Persistent incident history with 90-day retention
- Complete workflow orchestration with Step Functions

## Architecture Philosophy

The system mirrors production incident management platforms (Resolve AI, PagerDuty AIOps, Datadog Watchdog) where specialized agents collect context in parallel, a correlation layer normalizes data, and an LLM synthesizes insights for human operators. Humans remain in control - the AI provides recommendations but has no permissions to modify infrastructure.
