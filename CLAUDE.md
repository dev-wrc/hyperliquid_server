# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a local WebSocket server that provides real-time order book data for Hyperliquid trading pairs. It connects to a Hyperliquid non-validating node and exposes WebSocket endpoints for `l2book`, `l4book`, and `trades` subscriptions. The server is written in Rust and uses file-based event sourcing to consume data from the node.

**Important**: This is a standalone educational project, not maintained by Hyperliquid Labs core team. Use at your own risk.

## Architecture

### Project Structure

The repository is organized as a Cargo workspace with two main packages:

- **`server/`**: Core library crate containing all business logic
  - `listeners/`: File system watchers that consume data from the Hyperliquid node
    - `directory.rs`: Generic directory monitoring trait
    - `order_book/`: Parses node data (fills, order diffs, statuses) and maintains order book state
  - `order_book/`: In-memory order book data structures
    - `levels.rs`: L2 (price level aggregation) logic
    - `linked_list.rs`: Custom linked list for order tracking
    - `multi_book.rs`: Manages multiple order books (one per coin)
    - `types.rs`: Core types (Oid, Px, Sz, Coin, Side)
  - `servers/`: WebSocket server implementation
    - `websocket_server.rs`: Axum-based WebSocket server with subscription management
  - `types/`: Message types and subscription handling
    - `subscription.rs`: Client message parsing and subscription validation
    - `node_data.rs`: Types for data consumed from node (fills, order diffs, statuses)
    - `inner.rs`: Internal message formats (L2Book, L4Book, Trade)

- **`binaries/`**: Executable binaries
  - `websocket_server.rs`: Main server binary with CLI argument parsing
  - `example_client.rs`: Example WebSocket client for testing

### Key Design Patterns

1. **File-based Event Sourcing**: The server watches the `~/hl-node` directory for new files written by the Hyperliquid node. It processes fills, order statuses, and book diffs batched by block.

2. **Broadcast Architecture**: Internal messages are broadcast via tokio channels to all connected WebSocket clients. Each client maintains its own subscription set.

3. **Generic Order Book**: The `OrderBook<O>` type is generic over order representation, supporting both L2 (aggregated levels) and L4 (individual orders).

4. **Subscription Types**:
   - `l2book`: Aggregated order book levels (configurable depth up to 100 levels, default 20)
   - `l4book`: Full order-by-order book (sends snapshot then diffs)
   - `trades`: Real-time trade feed

5. **Self-validation**: The server periodically fetches snapshots from the node and compares against internal state. If a mismatch is detected, it exits.

## Development Commands

### Building and Running

```bash
# Build in release mode
cargo build --release

# Run the WebSocket server (requires running Hyperliquid node)
cargo run --release --bin websocket_server -- --address 0.0.0.0 --port 8000

# Run with logging enabled
RUST_LOG=info cargo run --release --bin websocket_server -- --address 0.0.0.0 --port 8000

# Tune WebSocket compression (0-9, where 0=disabled, 1=default, 9=highest)
cargo run --release --bin websocket_server -- --address 0.0.0.0 --port 8000 --websocket-compression-level 5

# Run the example client
cargo run --bin example_client
```

### Testing

```bash
# Run all tests
cargo test

# Run tests for a specific module
cargo test --lib order_book

# Run a specific test
cargo test test_name

# Run tests with output
cargo test -- --nocapture
```

### Code Quality

```bash
# Format code
cargo fmt

# Check for warnings (extensive linting enabled via workspace lints)
cargo clippy

# Check without building
cargo check
```

## Prerequisites

**Critical**: This server requires a running Hyperliquid non-validating node from [`hyperliquid-dex/node`](https://github.com/hyperliquid-dex/node) with:
- Batching by block enabled
- Recording of fills, order statuses, and raw book diffs

The server expects node data in `~/hl-node` directory.

## Server Behavior

- **Auto-exit on staleness**: If no new events are detected for 5 seconds, the server exits
- **Auto-exit on state divergence**: If internal state differs from node snapshot, the server exits
- **No spot support**: Currently only perpetual futures are supported
- **No trigger orders**: Untriggered stop/take-profit orders are not shown in the order book

## Code Style

The workspace enforces strict linting rules (see `Cargo.toml`):
- Most clippy lint groups enabled at warn level (`pedantic`, `nursery`, `cargo`)
- No `unwrap()` or `expect()` allowed (except in tests)
- Comprehensive Rust lint rules including `unsafe_code` warnings

Formatting uses `rustfmt.toml`:
- Max line width: 120
- Crate-level import granularity
- Grouped imports (std, external, crate)
