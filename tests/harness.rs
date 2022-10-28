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

    // this is the default wallet that will get used if no other one is specified
    let wallet_1 = wallets.get(0).unwrap();
    // println!("WALLET_1: {:?}", wallet_1);
    let wallet_2 = wallets.get(1).unwrap();
    // println!("WALLET_2: {:?}", wallet_2);
    let wallet_3 = wallets.get(2).unwrap();
    // println!("WALLET_3: {:?}", wallet_3);


    let wallet_1_address: Address = wallet_1.clone().address().into();
    let wallet_1_id = Identity::Address(wallet_1_address);

    let wallet_2_address: Address = wallet_2.clone().address().into();
    let wallet_2_id = Identity::Address(wallet_2_address);

    let wallet_3_address: Address = wallet_3.clone().address().into();
    let wallet_3_id = Identity::Address(wallet_3_address);

    // project1 params
    let metadata: fuels::core::types::SizedAsciiString<5> =
        "abcde".try_into().expect("Should have succeeded");
    let price: u64 = 1;

    // make a project
    let project1 = instance.list_project(price, metadata).call().await.unwrap();

    // get project1
    let project1_copy = instance.get_project(0).call().await.unwrap();

    // make sure the project we made is equal to the project we got
    assert!(project1.value == project1_copy.value);
    assert!(project1.value.price == price);
    assert!(project1_copy.value.price == price);
    println!("Project 1 created: {:?}", project1.value);

    
    let creator_vector_1 = instance.get_creator_vector(wallet_1_id.clone()).call().await.unwrap();
    println!("Creator Vector 1: {:?}", creator_vector_1.value);

    let creator_vector_3 = instance.get_creator_vector(wallet_3_id.clone()).call().await.unwrap();
    println!("Creator Vector 3 BEFORE: {:?}", creator_vector_3.value);

    // project2 params
    let metadata2: fuels::core::types::SizedAsciiString<5> =
        "12345".try_into().expect("Should have succeeded");
    let price2: u64 = 25;

    // make a project from wallet_3
    let project2 = instance
        ._with_wallet(wallet_3.clone())
        .unwrap()
        .list_project(price2, metadata2)
        .call()
        .await
        .unwrap();

        println!("Project 2 created: {:?}", project2.value);

    // project3 params
    let metadata3: fuels::core::types::SizedAsciiString<5> =
        "sarah".try_into().expect("Should have succeeded");
    let price3: u64 = 33;

    // make another project from wallet_3
    let project3 = instance
        ._with_wallet(wallet_3.clone())
        .unwrap()
        .list_project(price3, metadata3)
        .call()
        .await
        .unwrap();

        println!("Project 3 created: {:?}", project3.value);

        let creator_vector_3_copy = instance.get_creator_vector(wallet_3_id.clone()).call().await.unwrap();
        println!("Creator Vector 3 AFTER: {:?}", creator_vector_3_copy.value);


    // check if creator list was updated
    let creator_list_length = instance
        .get_creator_list_length(wallet_3_id.clone())
        .call()
        .await
        .unwrap();
    println!("Creator List Length: {:?}", creator_list_length.value);
    assert!(creator_list_length.value > 0);
    

    // make sure 3 projects have been created in total
    let total_projects = instance.get_projects_list_length().call().await.unwrap();
    println!("TOTAL PROJECTS: {:?}", total_projects.value);
    assert!(total_projects.value == 3);

    // Bytes representation of the asset ID of the "base" asset used for gas fees.
    pub const BASE_ASSET_ID: AssetId = AssetId::new([0u8; 32]);

    // call params to send the project price in the buy_project fn
    let call_params = CallParameters::new(Some(price), Some(BASE_ASSET_ID), None);

    // buy project 0 from wallet_2
    let _identity = instance
        ._with_wallet(wallet_2.clone())
        .unwrap()
        .buy_project(0)
        .call_params(call_params)
        .call()
        .await
        .unwrap();
    
    let call_params = CallParameters::new(Some(price), Some(BASE_ASSET_ID), None);

     // buy project 0 from wallet_3
     let _identity_2 = instance
     ._with_wallet(wallet_3.clone())
     .unwrap()
     .buy_project(0)
     .call_params(call_params)
     .call()
     .await
     .unwrap();

    // get the project made by wallet_1
    let project1_id = instance
        .get_created_project_id(wallet_1_id.clone(), 0)
        .call()
        .await
        .unwrap();
    println!("Project 1 id: {:?}", project1_id.value);
    println!("Identity looked for: {:?}", wallet_1_id);

    // get the first project wallet_3 minted
    let project2_id = instance
        .get_created_project_id(wallet_3_id.clone(), 0)
        .call()
        .await
        .unwrap();
    println!("Project 2 id: {:?}", project2_id.value);
    println!("Identity looked for: {:?}", wallet_3_id);

    // check if buyer list for wallet_2 was updated
    let mut buyer_list_length = instance
        .get_buyer_list_length(wallet_2_id.clone())
        .call()
        .await
        .unwrap();
    println!("Buyer List Length: {:?}", buyer_list_length.value);
    assert!(buyer_list_length.value > 0);

    let call_params_2 = CallParameters::new(Some(price2), Some(BASE_ASSET_ID), None);

    // buy project 1 from wallet_3
    let _identity_2 = instance
        ._with_wallet(wallet_3.clone())
        .unwrap()
        .buy_project(1)
        .call_params(call_params_2)
        .call()
        .await
        .unwrap();


    // check if buyer list was updated
    buyer_list_length = instance
        .get_buyer_list_length(wallet_3_id.clone())
        .call()
        .await
        .unwrap();
    println!("Buyer List Length: {:?}", buyer_list_length.value);
    assert!(buyer_list_length.value > 0);

    // check if has_project returns true
    let has_project = instance
        .has_bought_project(1, wallet_3_id.clone())
        .call()
        .await
        .unwrap();

    let val = has_project.value;

    println!("HAS PROJECT? {:?}", val);
    assert!(val == true);

    // review project 0 from wallet_2
    let _result = instance
    ._with_wallet(wallet_2.clone())
        .unwrap()
        .review_project(0, 4)
        .call()
        .await
        .unwrap();
    
    // review project 0 from wallet_3
    let _result_2 = instance
    ._with_wallet(wallet_3.clone())
        .unwrap()
        .review_project(0, 5)
        .call()
        .await
        .unwrap();

    // get project 0 ratings indexes
    let ratings = instance
        .get_project_ratings_ix(0)
        .call()
        .await
        .unwrap();
    println!("RATINGS: {:?}", ratings.value);


}
