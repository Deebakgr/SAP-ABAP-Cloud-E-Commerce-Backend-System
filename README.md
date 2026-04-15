# SAP ABAP Cloud: E-Commerce Backend System

An enterprise-grade E-commerce backend built using the **ABAP RESTful Programming Model (RAP)** on **SAP Business Technology Platform (BTP)**.

This project demonstrates a complete **Managed and Draft-enabled implementation** for managing:
- Orders
- Products
- Users
- Behavior Tracking

---

## 🚀 Technical Stack

- **Language:** ABAP Cloud (Steampunk)
- **Framework:** RESTful ABAP Programming Model (RAP)
- **Architecture:** Managed Scenario with Draft Capabilities
- **UI:** SAP Fiori Elements (List Report & Object Page)
- **Database:** SAP HANA (via Core Data Services - CDS)
- **Tools:** ABAP Development Tools (ADT) on Eclipse

---

## 📦 Key Applications

### 🛒 Orders Management
- Handles customer transactions with pricing & shipping
- Automatic **Total Price calculation**
- Dynamic **Order Status management**:
  - Confirmed
  - Shipped
  - Cancelled

### 📦 Product Catalog
- Inventory management system
- Supports:
  - Categories
  - Brands
  - Real-time stock tracking

### 👤 User Management
- Stores customer profiles
- Includes:
  - Segmentation (Premium, Standard, New)
  - Contact details

### 📊 Behavior Events
- Tracks user interactions:
  - View
  - Add to Cart
  - Purchase
- Calculates **engagement scores**

---

## ⚡ Advanced RAP Features Implemented

### 1. Robust Data Integrity (Draft Framework)
- Implemented **Crash-Proof Early Numbering system**
- Checks both:
  - Active table
  - Draft table
- Prevents:
  - Duplicate keys
  - Short dumps (`RAISE_SHORTDUMP`)
- Handles:
  - Abandoned drafts
  - Browser refresh scenarios

### 2. Intelligent Determinations & Validations

#### ⏱️ Automatic IST Time Stamping
- Converts UTC → IST using **+5.5 hours logic**
- Ensures regional accuracy for Indian operations

#### 💰 Price Calculation
- Calculates total based on:
  - Quantity
  - Unit price
  - Discount

#### ✅ Business Rules
- Validates mandatory fields
- Example:
  - Product ID must be filled before saving

### 3. Dynamic UI & Feature Control

#### 🎨 Criticality Coloring
- Fiori visual indicators:
  - 🟢 Green → Confirmed
  - 🔴 Red → Cancelled

#### 🔘 Action Buttons
- Dynamic enable/disable logic:
  - Confirm Order
  - Set to Shipped
  - View
  - Add to Cart

---

## 🏗️ Project Structure
ZI_* → Interface Views (Root Entities)
ZC_* → Projection Views (Consumption Layer)
ZBP_* → Behavior Pools (Business Logic Classes)
ZUI_* → Service Definitions & Bindings
ZMDX_* → Metadata Extensions (UI Annotations)


---

## 🎯 Key Highlights

- Full **Managed RAP implementation**
- **Draft-enabled transactional system**
- Strong **data integrity & validation logic**
- **Dynamic Fiori UI behavior**
- Scalable design aligned with **SAP BTP standards**
