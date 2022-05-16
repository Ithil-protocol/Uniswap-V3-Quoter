# Ithil Bug Bounty

## Overview

Starting from the public testnet release in XX/XX/XXXX we want to incentivize community involvement and pre-mainnet bug disclosure.
We are open to all severity bugs and are offering a reward of up to $5,000, happy hacking!

## Scope

The scope of the Program is limited to bugs that result in the draining of contract funds.

The following are not within the scope of the Program:

- Any contract located under [contracts/test](./contracts/test) or [contracts/mocks](./contracts/mocks).
- Bugs in any third party contract or platform that interacts with Ithil.
- Any already-reported bugs or issue on GitHub, Twitter or Discord.

Excluded from the bug bounty are the following:

- Frontend bugs
- DDOS attacks
- Spamming
- Phishing
- Automated tools errors (Github Actions, AWS, etc.)
- Attacks involving third-party systems or services (dex exploits)

## Assumptions

We assume the contract not to use mocks or mocked tokens and the whitelisted tokens strictly follow ERC20 specifications.

## Rewards

You will be awarded a prize depending on the severity of the bug and the top 3 white-hat hackers will receive a custom NFT and a future token airdrop.

## Disclosure

Any vulnerability or bug discovered must be reported only to the following email: [security@ithil.fi](mailto:security@ithil.fi).

The vulnerability must not be disclosed publicly or to any other person, entity or email address before Ithil team has been notified and has granted permission for public disclosure. In addition, disclosure must be made within 24 hours following discovery of the vulnerability.

A detailed report of a vulnerability increases the likelihood of a reward and may increase the reward amount. Please provide as much information about the vulnerability as possible, including:

- The conditions on which reproducing the bug is contingent.
- The steps needed to reproduce the bug or, preferably, a proof of concept.
- The potential implications of the vulnerability being abused.

Anyone who reports a unique, previously-unreported vulnerability that results in a change to the code or a configuration change and who keeps such vulnerability confidential until it has been resolved by our engineers will be recognized publicly for their contribution if they wish so.

## Other Terms

By submitting your report, you grant Ithil team any and all rights, including intellectual property rights, needed to validate, mitigate, and disclose the vulnerability. All reward decisions, including eligibility for and amounts of the rewards and the manner in which such rewards will be paid, are made at our sole discretion.
