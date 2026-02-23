#!/usr/bin/env python3
"""
Script to create and store the LLM prompt template in AWS Systems Manager Parameter Store.

This script creates a versioned prompt template (v1.0) that instructs the LLM on how to
analyze incident data and generate structured root-cause hypotheses.

Requirements: 16.1, 16.2, 16.3, 16.4, 16.5
"""

import boto3
import json
import sys
from botocore.exceptions import ClientError

# Prompt template version
PROMPT_VERSION = "v1.0"

# Parameter Store path
PARAMETER_NAME = "/incident-analysis/prompt-template"

# Prompt template content
PROMPT_TEMPLATE = """You are an expert Site Reliability Engineer analyzing an infrastructure incident.

ROLE: You are a senior SRE with deep expertise in AWS infrastructure, distributed systems, and incident response. Your goal is to help on-call engineers quickly understand and resolve production incidents.

TASK: Analyze the provided incident data and generate a root-cause hypothesis with supporting evidence. Your analysis should be actionable, evidence-based, and help engineers make informed decisions about remediation.

INPUT DATA:
{structured_context}

OUTPUT FORMAT (JSON):
{{
  "rootCauseHypothesis": "Single sentence hypothesis describing the most likely root cause",
  "confidence": "high|medium|low",
  "evidence": ["Specific data point 1 with exact values", "Specific data point 2 with exact values", "..."],
  "contributingFactors": ["Factor 1 that may have contributed", "Factor 2 that may have contributed", "..."],
  "recommendedActions": ["Specific action 1 with clear steps", "Specific action 2 with clear steps", "..."]
}}

INSTRUCTIONS:

1. ROOT CAUSE HYPOTHESIS:
   - Provide a single, clear sentence describing the most likely root cause
   - Base your hypothesis ONLY on the provided data (no speculation)
   - Focus on the immediate technical cause, not symptoms

2. CONFIDENCE LEVELS:
   - HIGH: Multiple correlated signals point to the same root cause (e.g., deployment + error spike + metric anomaly all aligned in time)
   - MEDIUM: Single strong signal or multiple weak signals suggest a root cause
   - LOW: Data is ambiguous, incomplete, or conflicting

3. EVIDENCE:
   - Cite specific metrics with exact values and timestamps
   - Quote relevant error messages from logs
   - Reference specific deployment or configuration changes with timestamps
   - Show temporal correlation between events (e.g., "Error rate increased from 0.1% to 15% within 2 minutes of deployment")
   - Provide at least 2-3 pieces of evidence for high confidence, 1-2 for medium/low

4. CONTRIBUTING FACTORS:
   - List secondary factors that may have amplified the issue
   - Include environmental conditions (high traffic, resource constraints)
   - Note any pre-existing conditions that made the system vulnerable

5. RECOMMENDED ACTIONS:
   - Provide 2-5 specific, actionable steps
   - Prioritize immediate mitigation over long-term fixes
   - Include rollback steps if a recent change is implicated
   - Be specific (e.g., "Increase Lambda memory from 512MB to 1024MB" not "Increase memory")
   - Consider both immediate remediation and investigation steps

CONSTRAINTS:
- Keep total response under 500 tokens
- Use only information present in the structured context
- If data is incomplete, acknowledge it in your confidence level
- Do not make assumptions about systems or configurations not mentioned in the data
- Focus on technical root causes, not organizational or process issues

ANALYSIS:"""


def create_parameter(ssm_client, parameter_name: str, template: str, version: str) -> bool:
    """
    Create or update the prompt template parameter in Parameter Store.
    
    Args:
        ssm_client: Boto3 SSM client
        parameter_name: Parameter Store path
        template: Prompt template content
        version: Template version
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Add version metadata to the description
        description = f"LLM prompt template for incident analysis (Version: {version})"
        
        # Create parameter with versioning enabled
        response = ssm_client.put_parameter(
            Name=parameter_name,
            Description=description,
            Value=template,
            Type='String',
            Overwrite=True,  # Allow updates
            Tags=[
                {'Key': 'Project', 'Value': 'AI-SRE-Portfolio'},
                {'Key': 'Component', 'Value': 'LLM-Analyzer'},
                {'Key': 'Version', 'Value': version}
            ]
        )
        
        print(f"✓ Successfully created parameter: {parameter_name}")
        print(f"  Version: {response['Version']}")
        print(f"  Template Version: {version}")
        return True
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        print(f"✗ Failed to create parameter: {error_code} - {error_message}")
        return False


def verify_parameter(ssm_client, parameter_name: str) -> bool:
    """
    Verify the parameter was created successfully.
    
    Args:
        ssm_client: Boto3 SSM client
        parameter_name: Parameter Store path
        
    Returns:
        True if parameter exists and is valid, False otherwise
    """
    try:
        response = ssm_client.get_parameter(Name=parameter_name)
        parameter = response['Parameter']
        
        print(f"\n✓ Parameter verification successful:")
        print(f"  Name: {parameter['Name']}")
        print(f"  Type: {parameter['Type']}")
        print(f"  Version: {parameter['Version']}")
        print(f"  Last Modified: {parameter['LastModifiedDate']}")
        print(f"  Size: {len(parameter['Value'])} characters")
        
        # Verify template contains key sections
        template = parameter['Value']
        required_sections = [
            'ROLE:',
            'TASK:',
            'INPUT DATA:',
            'OUTPUT FORMAT',
            'INSTRUCTIONS:',
            'CONFIDENCE LEVELS:',
            'EVIDENCE:',
            'CONSTRAINTS:'
        ]
        
        missing_sections = [section for section in required_sections if section not in template]
        if missing_sections:
            print(f"\n✗ Warning: Template missing sections: {missing_sections}")
            return False
        
        print(f"  ✓ All required sections present")
        return True
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        print(f"✗ Parameter verification failed: {error_code} - {error_message}")
        return False


def main():
    """Main function to create and verify the prompt template."""
    print("=" * 80)
    print("Creating LLM Prompt Template in Parameter Store")
    print("=" * 80)
    print(f"\nParameter Name: {PARAMETER_NAME}")
    print(f"Template Version: {PROMPT_VERSION}")
    print(f"Template Size: {len(PROMPT_TEMPLATE)} characters")
    
    # Initialize SSM client
    try:
        ssm_client = boto3.client('ssm')
        print(f"\n✓ Connected to AWS Systems Manager")
    except Exception as e:
        print(f"\n✗ Failed to initialize AWS client: {e}")
        print("\nPlease ensure:")
        print("  1. AWS credentials are configured (aws configure)")
        print("  2. You have permissions for ssm:PutParameter and ssm:GetParameter")
        sys.exit(1)
    
    # Create parameter
    print(f"\nCreating parameter...")
    if not create_parameter(ssm_client, PARAMETER_NAME, PROMPT_TEMPLATE, PROMPT_VERSION):
        sys.exit(1)
    
    # Verify parameter
    print(f"\nVerifying parameter...")
    if not verify_parameter(ssm_client, PARAMETER_NAME):
        sys.exit(1)
    
    print("\n" + "=" * 80)
    print("✓ Prompt template successfully created and verified!")
    print("=" * 80)
    print(f"\nThe LLM Analyzer Lambda function can now retrieve the template using:")
    print(f"  ssm_client.get_parameter(Name='{PARAMETER_NAME}')")
    print(f"\nTo update the template in the future:")
    print(f"  1. Increment PROMPT_VERSION (e.g., v1.1, v2.0)")
    print(f"  2. Update PROMPT_TEMPLATE content")
    print(f"  3. Run this script again")
    print(f"\nParameter Store will maintain version history automatically.")


if __name__ == "__main__":
    main()
