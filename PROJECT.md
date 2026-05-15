# VPN Hub Project Requirements

## 1. Project Goal

Build an easy-to-manage travel VPN solution using:

- **Home VPN Server SBC (Ubuntu)** inside the home network
- **Portable VPN Hub SBC (Ubuntu)** used in remote networks (hotel, apartment, coworking, etc.)

The VPN Hub must provide a local Wi-Fi hotspot for user devices, connect upstream to available remote Wi-Fi, then establish a VPN tunnel to the home VPN server so all client traffic is routed through the home network.

---

## 2. Scope

### In Scope

- Automated provisioning and configuration for both SBCs with `sudo` privileges.
- VPN server setup behind NAT with required inbound port forwarding.
- VPN hub setup with:
  - Wi-Fi hotspot (AP mode)
  - Client mode connection to remote Wi-Fi
  - Local management web UI
  - Captive portal / browser-based upstream authentication support
  - Automatic VPN connection to home server after upstream connectivity is ready
  - Full-tunnel routing for connected client devices
- Health checks, logs, and simple recovery/reconnect behavior.
- Documentation and scripts ready for Copilot Agent-driven implementation.

### Out of Scope (initial release)

- Multi-user account system in management UI.
- Native mobile app.
- Mesh/multi-hub orchestration.
- Enterprise-grade HA/failover.

---

## 3. Reference User Scenario (Primary Flow)

1. User powers on VPN Hub in a hotel room.
2. Hub boots and exposes its own Wi-Fi hotspot.
3. User connects laptop to hub hotspot.
4. User opens management page.
5. User selects hotel Wi-Fi and enters credentials.
6. If hotel Wi-Fi requires browser auth/captive portal, user can complete it via management flow.
7. Hub obtains stable internet through hotel Wi-Fi.
8. Hub automatically establishes VPN tunnel to home VPN server.
9. User laptop traffic is routed via VPN to home network.
10. User laptop behaves as if connected to home network (subject to home routing/firewall policy).

---

## 4. System Requirements

### 4.1 Hardware

- 2 Ubuntu-capable SBCs (one server, one hub) with reliable power supplies.
- Hub SBC must support dual-role Wi-Fi operation requirements:
  - Preferred: two Wi-Fi adapters (one upstream client, one AP)
  - Acceptable: one adapter only if chipset/driver supports stable AP+STA concurrency
- Optional Ethernet fallback for provisioning/debugging.

### 4.2 Software Baseline

- Ubuntu LTS on both devices.
- Time synchronization enabled (`systemd-timesyncd` or equivalent).
- SSH access and `sudo` permissions available for automation agent.
- Persistent service management via `systemd`.

### 4.3 Network Prerequisites

- Home router port forwarding configured to VPN server.
- Static DHCP lease or static IP for home VPN server.
- Public DNS name (recommended) for home endpoint.

---

## 5. Functional Requirements

### FR-1: Automated Provisioning

- Provide reproducible setup scripts/playbooks for both server and hub.
- Scripts must be idempotent (safe to rerun).
- Configuration values must be centralized in editable config files (no hardcoded secrets in scripts).

### Acceptance Criteria

- Fresh Ubuntu install can be fully configured non-interactively (except explicit credentials/secrets input).
- Re-running setup does not break existing configuration.

### FR-2: Home VPN Server

- Install and configure VPN server software (WireGuard preferred for v1).
- Expose VPN endpoint on configured UDP port.
- Enable IP forwarding and required firewall/NAT rules.
- Restrict inbound exposure to minimum required ports.

### Acceptance Criteria

- Hub can establish tunnel from external network.
- Tunnel survives reboot of server after boot completion.

### FR-3: Hub Local Hotspot

- On boot, hub starts AP with configurable SSID/passphrase.
- Hotspot provides DHCP/DNS to connected client devices.
- Management page reachable from hotspot clients by hostname/IP.

### Acceptance Criteria

- Client can connect to hotspot within 2 minutes after power-on.
- Connected client receives IP lease and can access management UI.

### FR-4: Hub Upstream Wi-Fi Connection

- Management UI allows scan/list/select of available upstream Wi-Fi networks.
- Support open and WPA2/WPA3-PSK networks.
- Save known networks and auto-reconnect by priority.

### Acceptance Criteria

- User can connect hub to a selected upstream network from UI.
- Hub restores saved upstream connection after reboot.

### FR-5: Captive Portal / Browser Authentication Support

- Detect likely captive portal condition (internet check mismatch/redirect).
- Provide user workflow to complete browser-based authentication from client device.
- Maintain state until portal auth is completed or timed out.

### Acceptance Criteria

- In captive-portal hotel environment, user can complete portal login using laptop browser while connected to hub hotspot.
- After auth, hub verifies internet reachability and proceeds to VPN connect.

### FR-6: VPN Tunnel Lifecycle on Hub

- Auto-start VPN once upstream internet is ready.
- Retry with exponential backoff on failure.
- Report status: disconnected/connecting/connected/error.
- Keepalive configured for NAT traversal.

### Acceptance Criteria

- Hub eventually connects when server is reachable.
- Temporary upstream disconnect triggers automatic VPN recovery.

### FR-7: Full-Tunnel Routing for Clients

- All client traffic from hotspot routes through VPN tunnel by default.
- Prevent traffic leaks outside VPN when tunnel is down (kill-switch behavior).
- DNS queries from clients are sent through VPN path.

### Acceptance Criteria

- Public IP seen by client reflects home network egress while VPN connected.
- When VPN drops, client internet is blocked or explicitly marked unavailable until tunnel recovers.

### FR-8: Management Interface

- Lightweight web UI accessible from local hotspot only by default.
- Show status cards for:
  - Hotspot state
  - Upstream Wi-Fi state
  - Captive portal state
  - VPN state
  - Last errors/log snippets
- Actions:
  - Scan/connect/disconnect upstream Wi-Fi
  - View and trigger captive portal flow
  - Restart VPN
  - Reboot hub

### Acceptance Criteria

- Non-technical user can complete end-to-end connection flow via UI without SSH.

### FR-9: Security

- Unique default credentials generated on first boot; forced password change in initial setup flow.
- Secrets stored with least privilege file permissions.
- Firewall enabled on both server and hub.
- Disable unnecessary services and remote exposure.
- Optional SSH key-only mode supported.

### Acceptance Criteria

- No plaintext secrets in repository.
- External port scan on home endpoint only shows expected VPN/SSH ports per policy.

### FR-10: Observability and Supportability

- Persistent logs for provisioning, network manager, VPN service, and management app.
- Provide diagnostics command/script to gather status bundle.
- Critical services supervised and auto-restarted by `systemd`.

### Acceptance Criteria

- Operator can run one command to collect useful troubleshooting output.

---

## 6. Non-Functional Requirements

- **Reliability:** Automatic recovery from transient upstream/VPN interruptions.
- **Usability:** Core hotel-connect workflow should require no CLI usage.
- **Performance:** Minimal latency overhead beyond VPN and remote network constraints.
- **Maintainability:** Config-driven architecture, modular scripts, clear docs.
- **Security:** Principle of least privilege, secure defaults, no secret leakage.

---

## 7. Technical Architecture (Implementation Target)

### 7.1 Components (Recommended)

- **VPN:** WireGuard
- **AP + DHCP/DNS:** `hostapd` + `dnsmasq` (or `NetworkManager` profile with equivalent behavior)
- **Upstream Wi-Fi mgmt:** `NetworkManager` + `nmcli` integration
- **Firewall/NAT:** `nftables` (preferred) or `iptables` with persistent rules
- **Management API/UI:** lightweight service (e.g., Python FastAPI/Flask or Node.js) bound to hotspot interface
- **Service orchestration:** `systemd` units and dependency ordering

### 7.2 Required Service Dependencies (Hub)

- hotspot service starts at boot
- management service starts after hotspot networking is ready
- upstream monitor service runs continuously
- VPN service starts only after upstream internet-ready signal
- routing/firewall policy enforced before client traffic forwarding

---

## 8. Milestones (Implementation-Ready Breakdown)

### Milestone 1 - Repository Foundation & Configuration Model

### Deliverables

- Project structure for:
  - `server/` provisioning
  - `hub/` provisioning
  - `shared/` config templates and scripts
- Environment/config schema (`.env` or YAML) for all user-tunable values.
- Secret handling pattern and `.example` files.

### Tasks

- Define required config keys (server endpoint, keys, SSID, hotspot subnet, etc.).
- Implement config validation script.
- Add bootstrap scripts for both devices.

### Exit Criteria

- Both devices pass config validation and dry-run provisioning steps.

### Milestone 2 - Home VPN Server Provisioning

### Deliverables

- Automated WireGuard server install/config.
- Firewall + forwarding setup.
- Systemd-managed VPN service.

### Tasks

- Generate and store server/client key material securely.
- Create `wg0` config template.
- Apply and verify kernel forwarding settings.
- Add connectivity test script from external network simulation.

### Exit Criteria

- Server accepts WireGuard handshakes from test client and routes traffic.

### Milestone 3 - Hub Hotspot + Management Access

### Deliverables

- Hub AP startup on boot.
- DHCP/DNS for hotspot subnet.
- Reachable management web page (initial status-only).

### Tasks

- Configure AP interface and security settings.
- Configure local DHCP scope and DNS forwarding behavior.
- Build base management service with health endpoint and status dashboard shell.

### Exit Criteria

- User device connects to hotspot and opens management page reliably.

### Milestone 4 - Upstream Wi-Fi and Captive Portal Workflow

### Deliverables

- UI/API for Wi-Fi scan/connect/disconnect.
- Saved network profiles and reconnect policy.
- Captive portal detection and guided auth flow.

### Tasks

- Integrate `nmcli` operations in backend.
- Add portal detection check (HTTP probes + redirect evaluation).
- Add management UI flow to help user complete portal auth in browser.

### Exit Criteria

- Hub connects to hotel-like network and reaches public internet after portal auth.

### Milestone 5 - VPN Lifecycle + Full Tunnel Enforcement

### Deliverables

- Automatic VPN connect after upstream readiness.
- Reconnect logic and status transitions.
- Kill-switch and DNS leak prevention rules.

### Tasks

- Implement tunnel health checks and retry backoff.
- Add firewall policy that only allows client egress via VPN.
- Validate routing table and DNS behavior for hotspot clients.

### Exit Criteria

- Hotspot clients use home egress IP; no direct internet leak when VPN down.

### Milestone 6 - Security Hardening

### Deliverables

- Initial credential setup flow and secure defaults.
- Hardened firewall/service exposure on both devices.
- Optional SSH hardening profile.

### Tasks

- Enforce strong password policy for management UI.
- Apply minimal-open-port firewall profiles.
- Lock down file permissions on all secret materials.

### Exit Criteria

- Security checklist passes and manual audit finds no critical gaps.

### Milestone 7 - Observability, Recovery, and Operations

### Deliverables

- Unified diagnostics script.
- Persistent structured logging.
- Service watchdog/recovery policies.

### Tasks

- Implement log collection command (`journalctl` + network + VPN status).
- Add systemd restart policies and failure alerts in UI.
- Document standard troubleshooting playbooks.

### Exit Criteria

- Operator can diagnose and recover common failures without reimaging device.

### Milestone 8 - End-to-End Validation & Release

### Deliverables

- End-to-end test checklist covering primary user scenario.
- Installation/operations documentation.
- Versioned release artifact/tag.

### Tasks

- Run scenario tests in at least:
  - open Wi-Fi environment
  - WPA-protected environment
  - captive portal environment
- Verify reboot persistence and power-cycle behavior.
- Finalize rollback and upgrade procedure.

### Exit Criteria

- All acceptance criteria in Section 5 are validated and documented.

---

## 9. Test & Validation Requirements

- Include automated checks where feasible (script tests, config validation).
- Maintain a manual test matrix for real network scenarios.
- Minimum mandatory end-to-end test cases:
  1. Boot hub and connect client to hotspot.
  2. Connect hub to upstream Wi-Fi from UI.
  3. Complete captive portal authentication.
  4. Confirm VPN tunnel establishment.
  5. Confirm client traffic exits via home network.
  6. Simulate upstream interruption and validate automatic recovery.
  7. Simulate VPN interruption and validate kill-switch behavior.

---

## 10. Implementation Assumptions for Copilot Agent

- Agent has SSH + `sudo` access to both SBCs.
- Agent can install Ubuntu packages and create/manage `systemd` services.
- Agent can modify network configurations, firewall rules, and VPN configs.
- Agent can run remote verification commands and collect logs.
- Manual user input may still be required for secrets and captive portal credentials.

---

## 11. Risks and Mitigations

- **Single Wi-Fi adapter instability in AP+STA mode**  
  Mitigation: prefer dual-adapter hub hardware; document compatibility list.

- **Captive portal implementations vary widely**  
  Mitigation: implement generic browser-auth path + fallback manual mode.

- **NAT/ISP restrictions at home server**  
  Mitigation: keepalive tuning, dynamic DNS, optional alternate ports.

- **Credential exposure risk**  
  Mitigation: strict secret handling, permissions, and no secret commits.

---

## 12. Definition of Done (Project-Level)

Project is done when:

1. A non-technical user can complete the full travel flow using management UI only.
2. Hub reliably connects upstream, authenticates if needed, and establishes VPN to home.
3. Client traffic from hub hotspot is fully tunneled to home with no leak on tunnel failure.
4. Provisioning is reproducible from clean Ubuntu installs on both SBCs.
5. Security and operational documentation is complete and tested in real-world-like conditions.
