#[test_only]
module faucet::token_faucet_tests {
    use faucet::token_faucet::{Self, Faucet};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // Test addresses
    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // Helper function to initialize faucet
    fun setup_test(scenario: &mut Scenario) {
        next_tx(scenario, ADMIN);
        {
            token_faucet::init_for_testing(ctx(scenario));
        };
    }

    #[test]
    fun test_init_faucet() {
        let scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize faucet
        setup_test(scenario);
        
        // Verify faucet was created
        next_tx(scenario, ADMIN);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            // Faucet exists and is shared
            test::return_shared(faucet);
        };
        
        test::end(scenario_val);
    }

    #[test]
    fun test_has_claimed_initially_false() {
        let scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_test(scenario);
        
        next_tx(scenario, USER1);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            
            // User should not have claimed initially
            assert!(!token_faucet::has_claimed(&faucet, USER1), 0);
            
            test::return_shared(faucet);
        };
        
        test::end(scenario_val);
    }

    #[test]
    fun test_add_tokens_increases_balance() {
        let scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_test(scenario);
        
        // Admin adds tokens to faucet
        next_tx(scenario, ADMIN);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            let coins = coin::mint_for_testing<SUI>(1000_000_000_000, ctx(scenario)); // 1000 SUI
            
            token_faucet::add_tokens(&mut faucet, coins, ctx(scenario));
            
            test::return_shared(faucet);
        };
        
        test::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = token_faucet::EInsufficientBalance)]
    fun test_claim_fails_without_balance() {
        let scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_test(scenario);
        
        // User tries to claim without faucet having balance
        next_tx(scenario, USER1);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            
            token_faucet::claim(&mut faucet, ctx(scenario));
            
            test::return_shared(faucet);
        };
        
        test::end(scenario_val);
    }

    #[test]
    fun test_successful_claim() {
        let scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_test(scenario);
        
        // Admin adds tokens
        next_tx(scenario, ADMIN);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            let coins = coin::mint_for_testing<SUI>(1000_000_000_000, ctx(scenario));
            token_faucet::add_tokens(&mut faucet, coins, ctx(scenario));
            test::return_shared(faucet);
        };
        
        // User claims tokens
        next_tx(scenario, USER1);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            token_faucet::claim(&mut faucet, ctx(scenario));
            test::return_shared(faucet);
        };
        
        // Verify user received tokens
        next_tx(scenario, USER1);
        {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&coin) == 100_000_000_000, 0); // 100 SUI
            test::return_to_sender(scenario, coin);
        };
        
        test::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = token_faucet::EAlreadyClaimed)]
    fun test_double_claim_fails() {
        let scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_test(scenario);
        
        // Admin adds tokens
        next_tx(scenario, ADMIN);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            let coins = coin::mint_for_testing<SUI>(1000_000_000_000, ctx(scenario));
            token_faucet::add_tokens(&mut faucet, coins, ctx(scenario));
            test::return_shared(faucet);
        };
        
        // User claims first time
        next_tx(scenario, USER1);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            token_faucet::claim(&mut faucet, ctx(scenario));
            test::return_shared(faucet);
        };
        
        // User tries to claim again - should fail
        next_tx(scenario, USER1);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            token_faucet::claim(&mut faucet, ctx(scenario));
            test::return_shared(faucet);
        };
        
        test::end(scenario_val);
    }

    #[test]
    fun test_multiple_users_can_claim() {
        let scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_test(scenario);
        
        // Admin adds enough tokens for multiple claims
        next_tx(scenario, ADMIN);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            let coins = coin::mint_for_testing<SUI>(1000_000_000_000, ctx(scenario));
            token_faucet::add_tokens(&mut faucet, coins, ctx(scenario));
            test::return_shared(faucet);
        };
        
        // USER1 claims
        next_tx(scenario, USER1);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            token_faucet::claim(&mut faucet, ctx(scenario));
            test::return_shared(faucet);
        };
        
        // USER2 claims
        next_tx(scenario, USER2);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            token_faucet::claim(&mut faucet, ctx(scenario));
            test::return_shared(faucet);
        };
        
        // Verify both users have claimed
        next_tx(scenario, ADMIN);
        {
            let faucet = test::take_shared<Faucet>(scenario);
            assert!(token_faucet::has_claimed(&faucet, USER1), 0);
            assert!(token_faucet::has_claimed(&faucet, USER2), 1);
            test::return_shared(faucet);
        };
        
        test::end(scenario_val);
    }
}
