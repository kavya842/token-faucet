module faucet::token_faucet {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    /// Error codes
    const EAlreadyClaimed: u64 = 0;
    const EInsufficientBalance: u64 = 1;

    /// Amount to distribute per claim (100 SUI)
    const CLAIM_AMOUNT: u64 = 100_000_000_000; // 100 SUI in MIST

    /// The faucet object that holds tokens and tracks claims
    struct Faucet has key {
        id: UID,
        balance: Balance<SUI>,
        claimed_addresses: Table<address, bool>
    }

    /// Event emitted when tokens are claimed
    struct TokensClaimed has copy, drop {
        claimer: address,
        amount: u64
    }

    /// Event emitted when tokens are added to faucet
    struct TokensAdded has copy, drop {
        amount: u64,
        faucet_balance: u64
    }

    /// Initialize the faucet
    fun init(ctx: &mut TxContext) {
        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero(),
            claimed_addresses: table::new(ctx)
        };
        transfer::share_object(faucet);
    }

    #[test_only]
    /// Test-only function to initialize faucet
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    /// Claim tokens from faucet
    entry fun claim(
        faucet: &mut Faucet,
        ctx: &mut TxContext
    ) {
        let claimer = tx_context::sender(ctx);
        
        // Check if address has already claimed
        assert!(!has_claimed(faucet, claimer), EAlreadyClaimed);
        
        // Check if faucet has sufficient balance
        assert!(balance::value(&faucet.balance) >= CLAIM_AMOUNT, EInsufficientBalance);
        
        // Transfer tokens to claimer
        let claim_balance = balance::split(&mut faucet.balance, CLAIM_AMOUNT);
        let claim_coin = coin::from_balance(claim_balance, ctx);
        transfer::public_transfer(claim_coin, claimer);
        
        // Mark address as claimed
        table::add(&mut faucet.claimed_addresses, claimer, true);
        
        // Emit event
        event::emit(TokensClaimed {
            claimer,
            amount: CLAIM_AMOUNT
        });
    }

    /// Admin function to add more tokens to faucet
    public fun add_tokens(
        faucet: &mut Faucet,
        tokens: Coin<SUI>,
        _ctx: &mut TxContext
    ) {
        let added_amount = coin::value(&tokens);
        let token_balance = coin::into_balance(tokens);
        balance::join(&mut faucet.balance, token_balance);
        
        // Emit event
        event::emit(TokensAdded {
            amount: added_amount,
            faucet_balance: balance::value(&faucet.balance)
        });
    }

    /// Check if an address has claimed
    public fun has_claimed(
        faucet: &Faucet,
        addr: address
    ): bool {
        table::contains(&faucet.claimed_addresses, addr)
    }
}
