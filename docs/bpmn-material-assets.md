# BPMN: Material Asset Accounting (diploma_backend)

```mermaid
flowchart LR
    %% Swimlanes
    subgraph E[Employee]
      E1([Start]) --> E2[Login]
      E2 --> E3[Create grab request]
      E2 --> E4[Create location change request]
      E2 --> E5[Return grabbed item]
    end

    subgraph M[Materially Responsible Person]
      M1[Review incoming requests]
      M2{{Approve request?}}
      M3[Approve grab / transfer]
      M4[Approve location request]
      M5[Reject request]
      M6[Move item to broken]
      M7[Perform inventory scan]
      M8[Complete inventory]
    end

    subgraph A[Accountant / Admin]
      A1[Create inventory draft]
      A2[Select items and MRP]
      A3[Submit inventory]
      A4[Final approve inventory]
      A5[Direct approve transfer/location]
      A6[Manage users, roles, assignments]
    end

    subgraph S[Backend System]
      S1[(users, user_tokens)]
      S2[(items, item_locations, item_parameters)]
      S3[(user_items)]
      S4[(item_location_requests)]
      S5[(broken_items)]
      S6[(inventory_requests, inventory_request_items)]
      S7[(item_journal_events)]
      S8[(audit_logs)]
      S9([End])
    end

    %% Grab/transfer flow
    E3 --> S3
    S3 --> M1
    M1 --> M2
    M2 -- Yes --> M3
    M2 -- No --> M5
    M3 --> S3
    M3 --> S7
    M3 --> S8

    %% Location flow
    E4 --> S4
    S4 --> M1
    M2 -- Yes --> M4
    M4 --> S2
    M4 --> S4
    M4 --> S7
    M4 --> S8

    %% Return flow
    E5 --> S3
    E5 --> S7
    E5 --> S8

    %% Broken flow
    M6 --> S5
    M6 --> S7
    M6 --> S8

    %% Inventory flow
    A1 --> A2 --> A3 --> S6
    S6 --> M7 --> S6
    M7 --> M8 --> S6
    M8 --> A4 --> S6
    A4 --> S8

    %% Direct privileged operations
    A5 --> S3
    A5 --> S2
    A5 --> S7
    A5 --> S8

    %% Admin settings
    A6 --> S1
    A6 --> S2
    A6 --> S8

    %% End
    M5 --> S8 --> S9
```

## Notes

- Role gates are enforced in service layer (`Default*Service`).
- Controllers are HTTP-only (decode/call service/map error/audit).
- Repositories isolate DB access (Fluent).
- Journaling (`item_journal_events`) stores domain events; `audit_logs` stores API audit trail.
