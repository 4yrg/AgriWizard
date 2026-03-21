# **Smart Greenhouse Ecosystem: Microservice Specifications**

This document outlines the core microservices that form the Smart Greenhouse Management System. Each service is designed to be independently deployable, containerized via Docker, and integrated into a De vSecOps CI/CD pipeline.

### **1\. Hardware Monitor & Controller Service**

**Role:** The primary bridge between physical IoT hardware and the cloud.

* **Device Enrollment:** API endpoints to register, provision, and decommission new sensors or actuators (fans, pumps, lights).  
* **Dynamic Parameter Types:** Capability to define new metrics (e.g., pH, NPK, CO2, Light Intensity) via the database without requiring code redeployment.  
* **MQTT Topic Manager:** Dynamically generates and manages MQTT subscribe/publish topics based on registered device IDs for secure data isolation.  
* **Manual Override Controller:** Provides secure REST endpoints to manually toggle hardware states, allowing users to override automated schedules.  
* **Device Health Check:** Monitors "heartbeat" signals from hardware to detect connectivity issues or sensor failures in real-time.

### **2\. Identity & Access Management (IAM)**

**Role:** The security provider for the entire ecosystem, ensuring the "Principle of Least Privilege."

* **User Authentication:** Secure sign-up and login functionality for different stakeholders (Farmers, Technicians, Administrators).  
* **JWT Token Issuance:** Generates signed JSON Web Tokens (JWT) upon successful login to facilitate secure stateless communication between services.  
* **Role-Based Access Control (RBAC):** Manages permissions to ensure only authorized users (e.g., Admins) can trigger manual overrides or change thresholds.  
* **Token Introspection:** Provides a validation endpoint for other microservices to verify the authenticity and expiration of user tokens.  
* **Profile Management:** Stores and updates user-specific contact information and preferences for localized greenhouse management.

### **3\. Smart Dashboard & Scheduler Service**

**Role:** Transforms raw sensor data into actionable insights and automated logic routines.

* **Periodic Data Aggregation:** Automatically calculates hourly, daily, and weekly averages for soil and environmental parameters to identify growth patterns.  
* **Threshold & Safe Zone Management:** Allows users to define specific ranges (e.g., "Moisture: 30%-60%") that trigger automated irrigation or ventilation.  
* **Historical Trend Analysis:** Provides summarized data for frontend visualization, showing growth conditions over the last 30 days.  
* **Predictive Irrigation Logic:** Suggests watering needs based on current moisture trends, soil types, and processed historical data.  
* **Operation Scheduler:** Manages time-based rules for greenhouse equipment, such as daily lighting cycles or periodic fan rotations.

### **4\. Alert & Notification Service**

**Role:** Manages all outbound communications and logs system-critical events for human intervention.

* **Multi-Channel Dispatch:** Integrates with cloud notification services (e.g., AWS SNS or SendGrid) to send Email, SMS, or Push notifications.  
* **Dynamic Template Engine:** Formats alert messages based on the event type, injecting real-time values (e.g., "Critical: pH level is 4.5 in Zone A").  
* **Recipient Routing:** Intelligently maps alerts to the correct user; technical failures go to the Admin, while moisture alerts go to the Farmer.  
* **Alert Throttling:** Implements logic to prevent "notification fatigue" by limiting the frequency of alerts for the same repeating issue.  
* **Delivery Tracking & Audit:** Logs a history of all sent notifications, including timestamps and delivery status, for future audit reports.

### **5\. External Weather Intelligence Service**

**Role:** Adds a layer of "smart" automation by integrating with third-party cloud APIs.

* **Live Weather Integration:** Fetches current local weather data (outside temperature, humidity, wind speed) via a third-party external API (e.g., OpenWeatherMap).  
* **Rain Forecast Analysis:** Analyzes upcoming precipitation data to determine if scheduled automatic watering should be delayed or skipped to conserve water.  
* **Extreme Event Warnings:** Monitors for local storm, frost, or heatwave warnings and relays critical status updates to the Alert & Notification Service.  
* **Climate Comparison:** Compares internal greenhouse conditions with external ambient weather to optimize ventilation and energy efficiency.  
* **Irrigation Adjuster:** Provides "Scale Factors" to the Controller service (e.g., "Ambient temp is 35°C; increase watering duration by 20%").