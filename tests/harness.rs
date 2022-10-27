use fuels::{prelude::*, tx::ContractId};

// Load abi from json
abigen!(MyContract, "out/debug/webgum-contract-abi.json");

async fn get_contract_instance() -> (MyContract, ContractId, Vec<WalletUnlocked>) {
    // Launch a local network and deploy the contract
    let wallets = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(4),             /* Four wallets */
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

    // get access to some test wallets

    // this is the default wallet that will be used
    // let wallet_1 = wallets.get(0).unwrap();

    // println!("WALLETS VECTOR LENGTH: {:?}", wallets.len());

    let wallet_2 = wallets.get(1).unwrap();
    // println!("WALLET_2: {:?}", wallet_2);
    let wallet_3 = wallets.get(2).unwrap();
    // println!("WALLET_3: {:?}", wallet_3);

    // project1 params
    let metadata: fuels::core::types::SizedAsciiString<5> =
        "abcde".try_into().expect("Should have succeeded");
    let price: u64 = 1;

    // make a project
    let project1 = instance
    .list_project(price, metadata)
    .call()
    .await.unwrap();

    // get project1
    let project1_copy = instance
    .get_project(0)
    .call()
    .await.unwrap();

    // make sure the project we made is equal to the project we got
    assert!(project1.value == project1_copy.value);
    assert!(project1.value.price == price);
    assert!(project1_copy.value.price == price);
    // println!("Project created: {:?}", project1.value);

    // project2 params
    let metadata2: fuels::core::types::SizedAsciiString<5> =
        "12345".try_into().expect("Should have succeeded");
    let price2: u64 = 25;

     // make a project from wallet_2
     let project2 = instance
     ._with_wallet(wallet_3.clone())
     .unwrap()
     .list_project(price2, metadata2)
     .call()
     .await.unwrap();

     let wallet_3_address: Address = wallet_3.clone().address().into();
 
     // check if creator list was updated
     let creator_list_length = instance
     .get_creator_list_length(Identity::Address(wallet_3_address))
     .call()
     .await.unwrap();
    // println!("Creator List Length: {:?}", creator_list_length.value);
    assert!(creator_list_length.value > 0);

     // get created project for wallet_2
     let project2_copy = instance
     .get_created_project(Identity::Address(wallet_3_address), 0)
     .call()
     .await.unwrap();

    println!("Project 2 Copy: {:?}", project2_copy.value);
    println!("Project 2: {:?}", project2.value);
    // assert!(project2_copy.value == project2.value);

    

    // Bytes representation of the asset ID of the "base" asset used for gas fees.
    pub const BASE_ASSET_ID: AssetId = AssetId::new([0u8; 32]);

    // call params to send the project price in the buy_project fn
    let call_params = CallParameters::new(Some(price), Some(BASE_ASSET_ID), None);

    // buy project 0 from wallet_2
    let identity = instance
        ._with_wallet(wallet_2.clone())
        .unwrap()
        .buy_project(0)
        .call_params(call_params)
        .call()
        .await
        .unwrap();

    // check if buyer list was updated
    let mut buyer_list_length = instance
        .get_buyer_list_length(identity.value.clone())
        .call()
        .await
        .unwrap();
    // println!("Buyer List Length: {:?}", buyer_list_length.value);
    assert!(buyer_list_length.value > 0);

   

    let call_params_2 = CallParameters::new(Some(price), Some(BASE_ASSET_ID), None);

    // buy project 0 from wallet_3
    let _identity_2 = instance
        ._with_wallet(wallet_3.clone())
        .unwrap()
        .buy_project(0)
        .call_params(call_params_2)
        .call()
        .await
        .unwrap();

    // println!("IDENTITY: {:?}", identity_2.value);

    // check if buyer list was updated
    buyer_list_length = instance
        .get_buyer_list_length(identity.value.clone())
        .call()
        .await
        .unwrap();
    // println!("Buyer List Length: {:?}", buyer_list_length.value);
    assert!(buyer_list_length.value > 0);

    // check if has_project returns true
    let has_project = instance
        .has_bought_project(0, identity.value.clone())
        .call()
        .await
        .unwrap();

    let val = has_project.value;

    // println!("HAS PROJECT? {:?}", val);
    assert!(val == true);
}
