use fuels::{prelude::*, tx::ContractId};

// Load abi from json
abigen!(MyContract, "out/debug/webgum-contract-abi.json");

async fn get_contract_instance() -> (MyContract, ContractId, Vec<WalletUnlocked>) {
    // Launch a local network and deploy the contract
    let wallets = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(3),             /* Two wallets */
            Some(1),             /* Single coin (UTXO) */
            Some(1_000_000_000), /* Amount per coin */
        ),
        None,
    )
    .await;
    let wallet = wallets.get(0).unwrap();

    let id = Contract::deploy(
        "./out/debug/webgum-contract.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./out/debug/webgum-contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = MyContractBuilder::new(id.to_string(), wallet.clone()).build();

    (instance, id.into(), wallets)
}

#[tokio::test]
async fn can_get_contract_id() {
    let (instance, _id, wallets) = get_contract_instance().await;

    // Now you have an instance of your contract you can use to test each function

    let metadata: fuels::core::types::SizedAsciiString<5> =
        "abcde".try_into().expect("Should have succeeded");
    let price: u64 = 1;

    let result1 = instance.list_project(price, metadata).call().await.unwrap();
    let result2 = instance.get_project(0).call().await.unwrap();
    assert!(result1.value == result2.value);
    assert!(result1.value.price == price);
    assert!(result2.value.price == price);

    println!("Project created: {:?}", result1.value);

    let wallet_2 = wallets.get(0).unwrap();
    let wallet_3 = wallets.get(1).unwrap();

    println!("WALLET_2: {:?}", wallet_2);
    println!("WALLET_3: {:?}", wallet_3);

    // Bytes representation of the asset ID of the "base" asset used for gas fees.
    pub const BASE_ASSET_ID: AssetId = AssetId::new([0u8; 32]);

    let call_params = CallParameters::new(Some(price), Some(BASE_ASSET_ID), None);

    // buy project from wallet_2
    let identity = instance
        ._with_wallet(wallet_2.clone())
        .unwrap()
        .buy_project(0)
        .call_params(call_params)
        .call()
        .await
        .unwrap();

    println!("IDENTITY: {:?}", identity.value);

    // check if buyer list was updated
    let mut buyer_list_length = instance
        .get_buyer_list_length(identity.value.clone())
        .call()
        .await
        .unwrap();
    println!("Buyer List Length: {:?}", buyer_list_length.value);
    assert!(buyer_list_length.value > 0);

    let call_params_2 = CallParameters::new(Some(price), Some(BASE_ASSET_ID), None);

    // buy project from wallet_3
    let identity_2 = instance
        ._with_wallet(wallet_3.clone())
        .unwrap()
        .buy_project(0)
        .call_params(call_params_2)
        .call()
        .await
        .unwrap();

    println!("IDENTITY: {:?}", identity_2.value);

    // check if buyer list was updated
    buyer_list_length = instance
        .get_buyer_list_length(identity.value.clone())
        .call()
        .await
        .unwrap();
    println!("Buyer List Length: {:?}", buyer_list_length.value);
    assert!(buyer_list_length.value > 0);

    // check if has_project returns true
    let has_project = instance
        .has_bought_project(0, identity.value.clone())
        .call()
        .await
        .unwrap();

    let val = has_project.value;

    println!("HAS PROJECT? {:?}", val);
    assert!(val == true);
}
