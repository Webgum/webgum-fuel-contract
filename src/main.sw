contract;

use std::{
    storage::StorageVec,
    storage::StorageMap,
    identity::Identity,
    constants::BASE_ASSET_ID,
    option::Option,
    chain::auth::{AuthError, msg_sender},
    context::{call_frames::msg_asset_id, msg_amount, this_balance},
    token::transfer,
};

pub struct Project {
    projectId: u64,
    price: u64,
    ownerAddress: Identity,
    // use IPFS CID here?
    metadata: str[5],
}

pub enum InvalidError {
    IncorrectAssetId: (),
    NotEnoughTokens: (),
}

storage {
    // map of project ids to a vector of ratings
    // ratings: StorageMap<u64, Vec<u64>> = StorageMap {},
    buyers: StorageMap<Identity, Vec<u64>> = StorageMap {},
    creators: StorageMap<Identity, Vec<u64>> = StorageMap {},
    projectListings: StorageVec<Project> = StorageVec {},
    // commissionPercent: u64 = 420,
    // owner: Identity =  Identity::Address(ADDRESS_HERE);
}

abi WebGum {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project;

    // #[storage(read, write)]
    // fn update_project(projectId: u64, price: u64, metadata: str[50]) -> Project;

    #[storage(read, write)]
    fn buy_project(projectId: u64) -> Identity;

    // #[storage(read, write)]
    // fn reviewProject(projectId: u64, rating: u64);

    #[storage(read)]
    fn get_project(projectId: u64) -> Project;

    #[storage(read)]
    fn get_projects_list_length() -> u64;

    #[storage(read)]
    fn get_creator_list_length(creator: Identity) -> u64;

    #[storage(read)]
    fn get_created_project(creator: Identity, index: u64) -> Project;

    #[storage(read)]
    fn get_created_project_id(creator: Identity, index: u64) -> u64;

    #[storage(read)]
    fn get_buyer_list_length(buyer: Identity) -> u64;

    #[storage(read)]
    fn get_bought_project(buyer: Identity, index: u64) -> Project;

    #[storage(read)]
    fn has_bought_project(projectId: u64, wallet: Identity) -> bool;

    // #[storage(read, write)]
    // fn update_owner(identity: Identity);

}

impl WebGum for Contract {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project{
        let index = storage.projectListings.len();
        let sender: Result<Identity, AuthError> = msg_sender();

        let newProject =  Project {
            projectId: index,
            price: price,
            ownerAddress: sender.unwrap(),
            metadata: metadata,
        };

        // // check if creator already exists
        let mut existing: Vec<u64> = storage.creators.get(sender.unwrap());

        // add msg sender to creator list
        if existing.len() > 0 {
            existing.push(15);
            storage.creators.insert(sender.unwrap(), existing);
        } else {
            let mut creatorList = ~Vec::new();
            creatorList.push(22);
            storage.creators.insert(sender.unwrap(), creatorList);
        }
        storage.projectListings.push(newProject);

        return newProject
    }

    // #[storage(read, write)]
    // fn update_project(projectId: u64, price: u64, metadata: str[50]) -> Project{
    //     let project = storage.projectListings.get(projectId).unwrap()
        
    // }

    #[storage(read, write)]
    fn buy_project(projectId: u64) -> Identity {
        let asset_id = msg_asset_id();
        let amount = msg_amount();

        let project: Project = storage.projectListings.get(projectId).unwrap();

        // require payment
        require(asset_id == BASE_ASSET_ID, InvalidError::IncorrectAssetId);
        require(amount >= project.price, InvalidError::NotEnoughTokens);
        
        let sender: Result<Identity, AuthError> = msg_sender();

        // // check if buyer already exists
        let mut existing: Vec<u64> = storage.buyers.get(sender.unwrap());

        // add msg sender to buyer list
        if existing.len() < 1 {
            let mut buyerList = ~Vec::new();
            buyerList.push(projectId);
            storage.buyers.insert(sender.unwrap(), buyerList);
        } else {
            existing.push(projectId);
            storage.buyers.insert(sender.unwrap(), existing);
        }

        // // TO DO: add commission
        // //send the payout
        // this isn't working 
        // transfer(amount, asset_id, project.ownerAddress);

        let id: Identity = sender.unwrap();

        return id;
    }

    // #[storage(read, write)]
    // fn reviewProject(projectId: u64, rating: u64){

    // }

    #[storage(read)]
    fn get_project(projectId: u64) -> Project{
        storage.projectListings.get(projectId).unwrap()
    }

    #[storage(read)]
    fn get_projects_list_length() -> u64{
        storage.projectListings.len()
    }

    #[storage(read)]
    fn get_creator_list_length(creator: Identity) -> u64{
        storage.creators.get(creator).len()
    }

    #[storage(read)]
    fn get_created_project(creator: Identity, index: u64) -> Project{
        let projectId = storage.creators.get(creator).get(index).unwrap();
        storage.projectListings.get(projectId).unwrap()
    }

    #[storage(read)]
    fn get_created_project_id(creator: Identity, index: u64) -> u64{
        // storage.creators.get(creator).get(index).unwrap()
        let mut project_id = 55;
        match storage.creators.get(creator).get(0) {
            Option::Some(id) => project_id = id,
            Option::None => project_id = 66,
        }
        return project_id
    }

    #[storage(read)]
    fn get_buyer_list_length(buyer: Identity) -> u64{
        storage.buyers.get(buyer).len()
    }

    #[storage(read)]
    fn get_bought_project(buyer: Identity, index: u64) -> Project{
        let projectId = storage.buyers.get(buyer).get(index).unwrap();
        storage.projectListings.get(projectId).unwrap()
    }

    #[storage(read)]
    fn has_bought_project(projectId: u64, wallet: Identity) -> bool{
        let existing: Vec<u64> = storage.buyers.get(wallet);

        let mut i = 0;
        while i < existing.len() {
            let project = existing.get(i).unwrap();
            if project == projectId {
                return true;
            }
            i += 1;
        }

        return false;

    }

    // #[storage(read, write)]
    //  fn update_owner(identity: Identity) {
    //     storage.owner = Option::Some(identity);
    // }
}
