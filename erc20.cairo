use starknet::ContractAddress;

#[abi]
trait IERC20 {
    #[view]
    fn name() -> felt252;
    #[view]
    fn symbol() -> felt252;
    #[view]
    fn decimals() -> u8;
    #[view]
    fn total_supply() -> u256;
    #[view]
    fn totalSupply() -> u256;
    #[view]
    fn balance_of(account: ContractAddress) -> u256;
    #[view]
    fn balanceOf(account: ContractAddress) -> u256;
    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool;
    #[external]
    fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool;
    #[external]
    fn increaseAllowance(spender: ContractAddress, added_value: u256) -> bool;
    #[external]
    fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool;
    #[external]
    fn decreaseAllowance(spender: ContractAddress, subtracted_value: u256) -> bool;
}

#[contract]
mod ERC20 {
    use super::IERC20;
    use integer::BoundedInt;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        mint_amount: u256,
        pool_amount: u256,
        owner: ContractAddress,
        mint_friend: ContractAddress,
        pool_mint_friend: ContractAddress,
    }

    #[event]
    fn Transfer(from: ContractAddress, to: ContractAddress, value: u256) {}

    #[event]
    fn Approval(owner: ContractAddress, spender: ContractAddress, value: u256) {}

    impl ERC20 of IERC20 {
        fn name() -> felt252 {
            _name::read()
        }

        fn symbol() -> felt252 {
            _symbol::read()
        }

        fn decimals() -> u8 {
            18_u8
        }

        fn total_supply() -> u256 {
            _total_supply::read()
        }

        fn totalSupply() -> u256 {
            _total_supply::read()
        }

        fn balance_of(account: ContractAddress) -> u256 {
            _balances::read(account)
        }

        fn balanceOf(account: ContractAddress) -> u256 {
            _balances::read(account)
        }

        fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
            _allowances::read((owner, spender))
        }

        fn transfer(recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            _transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            let caller = get_caller_address();
            _spend_allowance(sender, caller, amount);
            _transfer(sender, recipient, amount);
            true
        }

        fn transferFrom(
            sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            let caller = get_caller_address();
            _spend_allowance(sender, caller, amount);
            _transfer(sender, recipient, amount);
            true
        }

        fn approve(spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            _approve(caller, spender, amount);
            true
        }

        fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
            _increaseAllowance(spender, added_value)
        }

        fn increaseAllowance(spender: ContractAddress, added_value: u256) -> bool {
            _increaseAllowance(spender, added_value)
        }

        fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
            _decreaseAllowance(spender, subtracted_value)
        }

        fn decreaseAllowance(spender: ContractAddress, subtracted_value: u256) -> bool {
            _decreaseAllowance(spender, subtracted_value)
        }
    }

    #[constructor]
    fn constructor(
        name: felt252, symbol: felt252, _owner: ContractAddress
    ) {
        initializer(name, symbol);
        mint_amount::write(0);
        pool_amount::write(0);
        owner::write(_owner);
    }
    
    #[view]
    fn name() -> felt252 {
        ERC20::name()
    }

    #[view]
    fn symbol() -> felt252 {
        ERC20::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        ERC20::decimals()
    }

    #[view]
    fn total_supply() -> u256 {
        ERC20::total_supply()
    }

    #[view]
    fn totalSupply() -> u256 {
        ERC20::totalSupply()
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        ERC20::balance_of(account)
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        ERC20::balanceOf(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        ERC20::allowance(owner, spender)
    }

    #[view]
    fn get_mint_amount() -> u256 {
        mint_amount::read()
    }

    #[view]
    fn get_pool_amount() -> u256 {
        pool_amount::read()
    }

    #[external]
    fn mint(recipient: ContractAddress, amount: u256) {
        let caller = get_caller_address();
        assert(caller == mint_friend::read(), 'not friend');
        if(mint_amount::read() + amount <= 1000000000000000000000000000){
           _mint(recipient, amount);
           mint_amount::write(mint_amount::read() + amount);
        }
    }

    #[external]
    fn poolMint(recipient: ContractAddress, amount: u256) {
        let caller = get_caller_address();
        assert(caller == pool_mint_friend::read(), 'not friend');
        if(pool_amount::read() + amount <= 100000000000000000000000000){
           _mint(recipient, amount);
           pool_amount::write(pool_amount::read() + amount);
        }
    }

    #[external]
    fn set_friend(_mint_friend: ContractAddress, _pool_mint_friend: ContractAddress){
        let caller = get_caller_address();
        assert(caller == owner::read(), 'not friend');
        mint_friend::write(_mint_friend);
        pool_mint_friend::write(_pool_mint_friend);
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer(recipient, amount)
    }

    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer_from(sender, recipient, amount)
    }

    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transferFrom(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20::approve(spender, amount)
    }

    #[external]
    fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        ERC20::increase_allowance(spender, added_value)
    }

    #[external]
    fn increaseAllowance(spender: ContractAddress, added_value: u256) -> bool {
        ERC20::increaseAllowance(spender, added_value)
    }

    #[external]
    fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        ERC20::decrease_allowance(spender, subtracted_value)
    }

    #[external]
    fn decreaseAllowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        ERC20::decreaseAllowance(spender, subtracted_value)
    }

    ///
    /// Internals
    ///

    #[internal]
    fn initializer(name_: felt252, symbol_: felt252) {
        _name::write(name_);
        _symbol::write(symbol_);
    }

    #[internal]
    fn _increaseAllowance(spender: ContractAddress, added_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) + added_value);
        true
    }

    #[internal]
    fn _decreaseAllowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) - subtracted_value);
        true
    }

    #[internal]
    fn _mint(recipient: ContractAddress, amount: u256) {
        assert(!recipient.is_zero(), 'ERC20: mint to 0');
        _total_supply::write(_total_supply::read() + amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(Zeroable::zero(), recipient, amount);
    }

    #[internal]
    fn _burn(account: ContractAddress, amount: u256) {
        assert(!account.is_zero(), 'ERC20: burn from 0');
        _total_supply::write(_total_supply::read() - amount);
        _balances::write(account, _balances::read(account) - amount);
        Transfer(account, Zeroable::zero(), amount);
    }

    #[internal]
    fn _approve(owner: ContractAddress, spender: ContractAddress, amount: u256) {
        assert(!owner.is_zero(), 'ERC20: approve from 0');
        assert(!spender.is_zero(), 'ERC20: approve to 0');
        _allowances::write((owner, spender), amount);
        Approval(owner, spender, amount);
    }

    #[internal]
    fn _transfer(sender: ContractAddress, recipient: ContractAddress, amount: u256) {
        assert(!sender.is_zero(), 'ERC20: transfer from 0');
        assert(!recipient.is_zero(), 'ERC20: transfer to 0');
        _balances::write(sender, _balances::read(sender) - amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(sender, recipient, amount);
    }

    #[internal]
    fn _spend_allowance(owner: ContractAddress, spender: ContractAddress, amount: u256) {
        let current_allowance = _allowances::read((owner, spender));
        if current_allowance != BoundedInt::max() {
            _approve(owner, spender, current_allowance - amount);
        }
    }
}
