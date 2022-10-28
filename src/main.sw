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
    project_id: u64,
    price: u64,
    ownerAddress: Identity,
    // use IPFS CID here?
    metadata: str[5],
    // rating: u64,
}

pub enum InvalidError {
    IncorrectAssetId: (),
    NotEnoughTokens: (),
    CantReview: (),
    InvalidRating: (),
}

struct Vector {
    inner: [u64; 5],
    current_ix: u64
}

impl Vector {
    fn new() -> Self {
        Self {
            inner: [0; 5],
            current_ix: 0,
        }
    }

    fn get(ref mut self, ix: u64) -> u64 { 
        self.inner[ix]
    }

    fn push(ref mut self, val: u64) {
        // only update if array not full
        match self.current_ix {
            0 => self.inner = [val, 0, 0, 0, 0],
            1 => self.inner = [self.inner[0], val, 0, 0, 0],
            2 => self.inner = [self.inner[0], self.inner[1], val, 0, 0],
            3 => self.inner = [self.inner[0], self.inner[1], self.inner[2], val, 0],
            4 => self.inner = [self.inner[0], self.inner[1], self.inner[2], self.inner[3], val],
            _ => revert(5),
        }
        self.current_ix = self.current_ix + 1; 
        
    }
}

storage {
    // ratings: a vector of tuples with the project id, the Identity, and the rating
    ratings: StorageVec<(u64, Identity, u64)> = StorageVec {},
    // ratings_map: map of project id => Vector of rating index locations
    ratings_map: StorageMap<u64, Vector> = StorageMap {},
    buyers: StorageMap<Identity, Vector> = StorageMap {},
    creators: StorageMap<Identity, Vector> = StorageMap {},
    project_listings: StorageVec<Project> = StorageVec {},
    // commissionPercent: u64 = 420,
    // owner: Identity =  Identity::Address(ADDRESS_HERE);
}

abi WebGum {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project;

    // #[storage(read, write)]
    // fn update_project(project_id: u64, price: u64, metadata: str[50]) -> Project;

    #[storage(read, write)]
    fn buy_project(project_id: u64) -> Identity;

    #[storage(read, write)]
    fn review_project(project_id: u64, rating: u64) -> u64;

    #[storage(read)]
    fn get_project(project_id: u64) -> Project;

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
    fn has_bought_project(project_id: u64, wallet: Identity) -> bool;

    // #[storage(read, write)]
    // fn update_owner(identity: Identity);

    #[storage(read)]
    fn get_creator_vector(id: Identity) -> Vector;

    #[storage(read)]
    fn get_buyer_vector(id: Identity) -> Vector;

    #[storage(read)]
    fn get_project_ratings_ix(project_id: u64) -> Vector;

}

impl WebGum for Contract {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project{
        let index = storage.project_listings.len() + 1;
        let sender: Result<Identity, AuthError> = msg_sender();

        let newProject =  Project {
            project_id: index,
            price: price,
            ownerAddress: sender.unwrap(),
            metadata: metadata,
            // rating: 0,
        };

        let mut existing: Vector = storage.creators.get(sender.unwrap());

        // add msg sender to buyer list
        existing.push(index);
        storage.creators.insert(sender.unwrap(), existing);

        storage.project_listings.push(newProject);

        return newProject
    }

    // #[storage(read, write)]
    // fn update_project(project_id: u64, price: u64, metadata: str[50]) -> Project{
    //     let project = storage.project_listings.get(project_id).unwrap()
        
    // }

    #[storage(read, write)]
    fn buy_project(project_id: u64) -> Identity {
        let asset_id = msg_asset_id();
        let amount = msg_amount();

        let project: Project = storage.project_listings.get(project_id).unwrap();

        // require payment
        require(asset_id == BASE_ASSET_ID, InvalidError::IncorrectAssetId);
        require(amount >= project.price, InvalidError::NotEnoughTokens);
        
        let sender: Result<Identity, AuthError> = msg_sender();

        let mut existing: Vector = storage.buyers.get(sender.unwrap());

        // add msg sender to buyer list
        existing.push(project_id);
        storage.buyers.insert(sender.unwrap(), existing);

        // TO DO: add commission
         //send the payout
         // this isn't working 
        // transfer(amount, asset_id, project.ownerAddress);

        let id: Identity = sender.unwrap();

        return id;
    }

    #[storage(read, write)]
    fn review_project(project_id: u64, rating: u64) -> u64{
        require(rating < 6, InvalidError::InvalidRating);
        let sender: Result<Identity, AuthError> = msg_sender();
        let mut existing: Vector = storage.buyers.get(sender.unwrap());
        let mut i = 0;
        let mut can_review = false;
        while i < existing.current_ix {
            let project = existing.get(i);
            if project == project_id {
                can_review = true;
            }
            i += 1;
        }

        // require sender has bought the project
        require(can_review, InvalidError::CantReview);
        let index = storage.ratings.len();
        // add rating to ratings vector
        storage.ratings.push((project_id, sender.unwrap(), rating));

        let mut existing: Vector = storage.ratings_map.get(project_id);
        // add rating index to ratings_map
        existing.push(index);
        storage.ratings_map.insert(project_id, existing);
        index
    }

    #[storage(read)]
    fn get_project(project_id: u64) -> Project{
        storage.project_listings.get(project_id).unwrap()
    }

    #[storage(read)]
    fn get_projects_list_length() -> u64{
        storage.project_listings.len()
    }

    #[storage(read)]
    fn get_creator_list_length(creator: Identity) -> u64{
        storage.creators.get(creator).current_ix
    }

    #[storage(read)]
    fn get_created_project(creator: Identity, index: u64) -> Project{
        let project_id = storage.creators.get(creator).get(index);
        storage.project_listings.get(project_id).unwrap()
    }

    #[storage(read)]
    fn get_created_project_id(creator: Identity, index: u64) -> u64{
        storage.creators.get(creator).get(index)
    }

    #[storage(read)]
    fn get_buyer_list_length(buyer: Identity) -> u64{
        storage.buyers.get(buyer).current_ix
    }

    #[storage(read)]
    fn get_bought_project(buyer: Identity, index: u64) -> Project{
        let project_id = storage.buyers.get(buyer).get(index);
        storage.project_listings.get(project_id).unwrap()
    }

    #[storage(read)]
    fn has_bought_project(project_id: u64, wallet: Identity) -> bool{
        let mut existing: Vector = storage.buyers.get(wallet);

        let mut i = 0;
        while i < existing.current_ix {
            let project = existing.get(i);
            if project == project_id {
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

    #[storage(read)]
    fn get_creator_vector(id: Identity) -> Vector {
        let val: Vector = storage.creators.get(id);
        val
    }

    #[storage(read)]
    fn get_buyer_vector(id: Identity) -> Vector {
        let val: Vector = storage.buyers.get(id);
        val
    }

    #[storage(read)]
    fn get_project_ratings_ix(project_id: u64) -> Vector {
        let val: Vector = storage.ratings_map.get(project_id);
        val
    }
}
