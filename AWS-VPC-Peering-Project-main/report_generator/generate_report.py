#!/usr/bin/env python3
"""
EWB Cloud Labs - AWS VPC Peering Report PDF Generator
Renders publication-ready PDF submission report according to the Page 13 grading rubric.
Includes embedded base64 evidence screenshots from live AWS Management Console verification.
"""

import os
import sys
import json
import base64
import subprocess
from datetime import datetime

DEFAULT_DATA = {
    "STUDENT_NAME": "Aditya Pawar",
    "STUDENT_BATCH": "AWS Architect Associate - Oct 2026",
    "AWS_REGION": "ap-south-1 (Mumbai)",
    "COMPLETION_DATE": datetime.now().strftime("%d %B %Y"),
    "ADMIN_IP": "122.170.198.164/32",
    "VPC_A_ID": "vpc-084a10c21275c9423",
    "VPC_B_ID": "vpc-0d5be64741a5ab8b9",
    "SUBNET_PUB_A_ID": "subnet-074a1bdc28f74eb7b",
    "SUBNET_PRIV_A_ID": "subnet-0739012e0e05001b3",
    "SUBNET_PRIV_B_ID": "subnet-083532ce04867e0d8",
    "IGW_A_ID": "igw-0852644c6bf4be208",
    "PEERING_ID": "pcx-078073f607a5a75f0",
    "BASTION_INSTANCE_ID": "i-006304f40baed16dc",
    "BASTION_PUBLIC_IP": "52.66.105.166",
    "APP_A_INSTANCE_ID": "i-0c4aabcc3f387bde1",
    "APP_B_INSTANCE_ID": "i-0e096e913d95c559a"
}

CHECKPOINT_IMAGE_MAP = {
    "IMG_KEYPAIR": "screenshots/checkpoints/01_key_pair_created.png",
    "IMG_VPC_A": "screenshots/checkpoints/02_vpc_a_created.png",
    "IMG_SUBNETS_A": "screenshots/checkpoints/03_subnets_vpc_a.png",
    "IMG_IGW_A": "screenshots/checkpoints/04_igw_attached.png",
    "IMG_RT_A_PUB": "screenshots/checkpoints/05_route_table_vpc_a_public.png",
    "IMG_RT_A_PRIV": "screenshots/checkpoints/06_route_table_vpc_a_private.png",
    "IMG_VPC_B": "screenshots/checkpoints/07_vpc_b_created.png",
    "IMG_RT_B_PRIV": "screenshots/checkpoints/08_route_table_vpc_b_private.png",
    "IMG_SG_BASTION": "screenshots/checkpoints/09_security_group_bastion.png",
    "IMG_SG_APPA": "screenshots/checkpoints/10_security_group_app_a.png",
    "IMG_SG_APPB": "screenshots/checkpoints/11_security_group_app_b.png",
    "IMG_EC2_RUNNING": "screenshots/checkpoints/12_ec2_instances_running.png",
    "IMG_BASTION_IP": "screenshots/checkpoints/13_bastion_public_ip.png",
    "IMG_PEERING_ACTIVE": "screenshots/checkpoints/14_vpc_peering_active.png",
    "IMG_PEERING_ROUTES": "screenshots/checkpoints/15_peering_routes_configured.png",
    "IMG_CONTROLLED_FAIL": "screenshots/checkpoints/16_controlled_failure_icmp_rule_deleted.png",
    "IMG_PEERING_DELETE": "screenshots/checkpoints/17_peering_deletion.png",
    "IMG_EC2_TERMINATED": "screenshots/checkpoints/18_ec2_instances_terminated.png",
}

def find_edge_binary():
    candidates = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None

def image_to_base64(filepath):
    if os.path.exists(filepath):
        try:
            with open(filepath, "rb") as f:
                encoded = base64.b64encode(f.read()).decode("utf-8")
                return f"data:image/png;base64,{encoded}"
        except Exception as e:
            print(f"[!] Warning reading image {filepath}: {e}")
    return ""

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, ".."))
    template_path = os.path.join(script_dir, "report_template.html")
    config_path = os.path.join(script_dir, "student_data.json")

    # Load custom student data if present
    data = DEFAULT_DATA.copy()
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                user_data = json.load(f)
                data.update(user_data)
            print(f"[+] Loaded custom config from {config_path}")
        except Exception as e:
            print(f"[!] Warning reading config: {e}")

    # Read template
    if not os.path.exists(template_path):
        print(f"[x] Template not found at {template_path}")
        sys.exit(1)

    with open(template_path, "r", encoding="utf-8") as f:
        html_content = f.read()

    # Load and embed checkpoint screenshots as Base64 data URIs
    print("[+] Embedding verification screenshots into report...")
    for tag, rel_path in CHECKPOINT_IMAGE_MAP.items():
        abs_img_path = os.path.join(project_root, rel_path)
        data_uri = image_to_base64(abs_img_path)
        placeholder = f"{{{{{tag}}}}}"
        html_content = html_content.replace(placeholder, data_uri)

    # Substitute student and infrastructure variables
    for key, val in data.items():
        placeholder = f"{{{{{key}}}}}"
        html_content = html_content.replace(placeholder, str(val))

    compiled_html_path = os.path.join(script_dir, "compiled_report.html")
    with open(compiled_html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"[+] Compiled self-contained HTML saved to: {compiled_html_path}")

    # Output PDF Name
    safe_name = "".join(c for c in data["STUDENT_NAME"] if c.isalnum() or c in (' ', '_')).strip().replace(' ', '_')
    pdf_filename = f"{safe_name}_EWB_VPC_Peering.pdf"
    output_pdf_path = os.path.join(project_root, pdf_filename)

    browser_bin = find_edge_binary()
    if not browser_bin:
        print("[!] Headless browser not found. HTML report is ready to be opened in any browser and saved as PDF.")
        print(f"[+] You can open: {compiled_html_path} and press Ctrl+P -> Save as PDF.")
        return

    print(f"[+] Generating PDF with headless browser: {browser_bin}")
    cmd = [
        browser_bin,
        "--headless",
        "--disable-gpu",
        "--run-all-compositor-stages-before-draw",
        f"--print-to-pdf={output_pdf_path}",
        "--no-pdf-header-footer",
        compiled_html_path
    ]

    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if os.path.exists(output_pdf_path) and os.path.getsize(output_pdf_path) > 0:
            size_kb = os.path.getsize(output_pdf_path) / 1024
            print(f"[SUCCESS] PDF generated successfully: {output_pdf_path} ({size_kb:.1f} KB)")
        else:
            print("[!] PDF generation finished but output file is missing or empty.")
    except Exception as e:
        print(f"[!] Error running browser PDF export: {e}")

if __name__ == "__main__":
    main()
