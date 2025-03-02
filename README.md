# rebase-token

> Cross-chain rebase token

1. A protocol that allows users to deposit into a vault and in return, receive a rebase token that represents the value of the deposited asset in the rebase currency.
2. Rebase token => bakanceOf function is dynamic, to show the changing balance with time.

- Balance increases linearly with time
- mint tokens to our users every time they perform an action

3. Interest Rate

- global interest rate
- individual interest rate for each user calculated at the time of deposit (snapshot)
- can only dicrease to incentivize/reward early users
- increase token adoption
