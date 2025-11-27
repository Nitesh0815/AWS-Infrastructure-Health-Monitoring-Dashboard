# AWS Infrastructure Health Monitoring Dashboard

## 📖 Executive Summary
This project solves a critical Cloud Support challenge:

### **❝ How do we verify that our critical AWS infrastructure is healthy and reachable? ❞**

This repository provides a **comprehensive serverless monitoring dashboard** integrating:

- **Compute** (EC2)  
- **Storage** (S3)  
- **Database** (RDS)  
- **Networking** (VPC, NAT, IGW)  
- **Automation** (Lambda + EventBridge)  
- **Alerting** (SNS)  
- **Observability** (CloudWatch Dashboard)

The project is implemented using **two methods**:

1. **Infrastructure as Code (IaC)** → Terraform  
2. **Manual Deployment** → AWS Management Console  

---

## 🏗 Architecture

![Architecture Diagram](architecture-diagram.png)

The solution deploys the following **high-availability AWS architecture**:

### **🔹 Network**
- Custom VPC (10.0.0.0/16)
- Public + Private subnets  
- Route Tables  
- NAT Gateway  
- Internet Gateway  

### **🔹 Compute**
- EC2 Web Server (Amazon Linux 2023, t3.micro)

### **🔹 Database**
- MySQL RDS instance in private subnet

### **🔹 Storage**
- S3 bucket with encryption enabled

### **🔹 Automation**
- Lambda (Python 3.11)  
- Tests internet connectivity  
- Triggered via EventBridge schedule

### **🔹 Observability**
- CloudWatch dashboard:
  - EC2 CPU  
  - RDS storage  
  - S3 size  
  - Lambda test results  

### **🔹 Alerting**
- SNS email alerts  
- CPU alarms  
- Network test failures  

---

## 📂 Repository Structure

```
AWS Infrastructure Health Monitoring Dashboard/
├── create resource using terraform/
│   ├── infra/
│   │   ├── main-template.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── versions.tf
│   ├── lambda/
│   │   └── network_tester.py
│   ├── screenshots/
│   └── AWS Infrastructure Health Monitoring Dashboard.docx
│
├── manually created resources/
│   ├── lambda/
│   │   └── network_tester.py
│   ├── screenshots/
│   └── AWS Infrastructure Health Monitoring Dashboard (1).docx
│
├── Architecture_diagram
└── README.md
```

---

## 🚀 Method 1: Deployment via Terraform

### Steps
```sh
cd "create resource using terraform/infra"
terraform init
terraform plan
terraform apply --auto-approve
```

Outputs include EC2 Public IP, RDS Endpoint, Dashboard URL.

---

## 🛠 Method 2: Manual Implementation

Covers:
- IAM setup  
- VPC + NAT  
- EC2 launch  
- S3 bucket  
- RDS MySQL  
- Lambda network test  
- CloudWatch dashboard  

---

## 🧪 Testing

### Lambda Network Test
- Success → logs success  
- Failure → SNS alert  

### EC2 Stress Test
```sh
sudo yum install -y stress
stress --cpu 1 --timeout 300s
```
Triggers CPU alarm + SNS email alert.

---

## 📸 Visuals
![CloudWatch_dashboard_image](manually%20created%20resources/screenshorts/114.png)

---

## 🧹 Clean Up

### Terraform
```sh
terraform destroy
```

### Manual
Delete NAT, RDS, EC2, S3, VPC.

---

## ✍ Author
Your Name  
Cloud Engineer & DevOps Enthusiast
