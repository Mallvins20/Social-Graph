# Social-Graph Smart Contract

A decentralized social graph contract for the Stacks blockchain, enabling users to follow and unfollow each other with efficient follower/following list management.

## Features

- **Follow/Unfollow:** Users can follow or unfollow other accounts.
- **Efficient Storage:** Follower and following lists are stored for O(1) access and removal.
- **Read-Only Views:** Query follower/following counts, check relationships, and get users by index.
- **Event Logging:** Emits events for follow and unfollow actions.

## Contract Overview

- Written in [Clarity](https://docs.stacks.co/docs/clarity-language/overview/), the smart contract language for Stacks.
- Maps and variables track relationships and counts.
- Functions:
  - `follow(user)`: Follow another user.
  - `unfollow(user)`: Unfollow a user.
  - `is-following(follower, followee)`: Check if a user follows another.
  - `get-followers-count(user)`: Get follower count.
  - `get-following-count(user)`: Get following count.
  - `get-follower-by-index(user, index)`: Get follower by index.
  - `get-followee-by-index(user, index)`: Get followee by index.
  - `get-total-follows()`: Get total follows globally.

## Usage

Deploy the contract to the Stacks blockchain. Interact with the public functions using your preferred Stacks wallet or development tools.

## Development

- **Clarity LSP:** Syntax and linting support.
- **Tests:** Place test files in the `tests/` directory.
- **Line Endings:** All files use LF (`* text=lf` in `.gitattributes`).
