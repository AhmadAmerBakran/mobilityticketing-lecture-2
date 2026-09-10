# Lecture 2 implementation lab: Make invalid states difficult to store

## Purpose

Strengthen the initial PostgreSQL schema for ticket purchase and validation. The focus is not API validation. The focus is what the database can guarantee when writes arrive from different applications, scripts, or future services.

## Starting point

The course starter infrastructure contains a deliberately weak schema for trips, products, tickets, payments, and validations. It accepts several states that conflict with the MobilityTicketing case.

Read the supplied DDL before changing anything. Add constraints through a new migration. Do not edit the starter DDL.

## Tasks

1. Extract at least ten domain invariants from the scenario and schema.
2. Classify each invariant as one of:
   - directly enforceable with a column or table constraint;
   - enforceable with a unique or exclusion rule;
   - dependent on more than one row or an external system;
   - currently ambiguous and requiring a domain decision.
3. Implement the constraints that belong in this lecture.
4. Write negative tests that attempt invalid inserts or updates.
5. Record at least two important invariants that cannot be solved by a simple constraint. Keep them for the transactions lecture.

## Minimum invariants to consider

- Capacity cannot be negative.
- Reserved seats cannot be negative or greater than capacity.
- Ticket price and payment amount cannot be negative.
- Currency must be present and consistently represented.
- Ticket codes must support unambiguous lookup.
- A payment must refer to an existing ticket.
- A validation must refer to an existing ticket.
- A ticket validity end cannot be earlier than its start.
- Status values must come from a known set.
- An external payment reference should not be recorded twice when it represents one captured payment.
- A validation must not combine the identifier of one ticket with the code of another.

## Required evidence

For every implemented invariant, include:

- the rule in plain language;
- the DDL used to enforce it;
- one write that succeeds;
- one write that fails;
- the database error or result that demonstrates enforcement.

Assert PostgreSQL SQLSTATE codes in automated tests where possible. Matching an English error string is brittle and language-dependent.

## State-transition trace

Trace ticket purchase and ticket validation at the row and relationship level. Describe which rows are inserted or updated and which references must already exist. Do not analyse concurrency yet.

## Delete and update behaviour

Inspect the relationships for historical tickets, payments, and validations. For each relationship, state whether deletion should be restricted, cascaded, soft-deleted, or governed by a retention policy. Also state whether an update should be allowed or rejected when it would change historical meaning.

## Integrity map

Create an integrity map that connects each business rule to its current owner, affected tables, expected failure behaviour, and remaining limitation.

## Important boundary

A row-level check can protect `reserved_seats <= capacity` for one row. It cannot arbitrate two concurrent purchases that both observe the same remaining capacity. Do not claim that this migration solves that race.

Payment capture across an external gateway and PostgreSQL also needs workflow design. A disabled-user purchase rule may be a domain or transaction policy depending on the case decision. Classify these limits explicitly.
