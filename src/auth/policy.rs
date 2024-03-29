use crate::util;
use rocket::serde::{Deserialize, Serialize};

#[cfg(test)]
#[path = "policy_tests.rs"]
mod policy_tests;

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(crate = "rocket::serde")]
pub struct User {
    pub login_name: String,
    pub full_name: Option<String>,
    pub groups: Vec<String>,
    pub policy_statements: Vec<PolicyStatement>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
pub struct Group {
    pub name: String,
    pub description: Option<String>,
    pub policy_statements: Vec<PolicyStatement>,
}

#[derive(Serialize, Deserialize, Debug, Copy, Clone, PartialEq, Eq)]
#[serde(crate = "rocket::serde")]
pub enum Effect {
    Allow,
    Deny,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(crate = "rocket::serde")]
pub struct PolicyStatement {
    pub effect: Effect,
    pub actions: Vec<String>,
    pub resources: Vec<String>,
}

impl PolicyStatement {
    fn matches_action(&self, action: &str) -> bool {
        self.actions
            .iter()
            .any(|pattern| util::glob_matches(pattern, action))
    }

    fn matches_resource(&self, resource: &str) -> bool {
        self.resources
            .iter()
            .any(|pattern| util::glob_matches(pattern, resource))
    }

    pub fn effect_on(&self, action: &str, resource: &str) -> Option<Effect> {
        if self.matches_action(action) && self.matches_resource(resource) {
            Some(self.effect)
        } else {
            None
        }
    }
}

pub trait PolicyStore {
    fn list_users(&self) -> Result<Vec<User>, ()>;
    fn user_named(&self, name: &str) -> Result<User, ()>;
    fn create_user(&self, user: &User) -> Result<(), ()>;
    fn update_user(&self, user: &User) -> Result<(), ()>;

    fn set_user_password(&self, login_name: &str, password: Option<&str>) -> Result<(), ()>;
    fn authenticate_user(&self, login_name: &str, password: &str) -> Result<User, ()>;

    fn list_groups(&self) -> Result<Vec<Group>, ()>;
    fn group_named(&self, name: &str) -> Option<Group>;
    fn create_group(&self, group: &Group) -> Result<(), ()>;
    fn update_group(&self, group: &Group) -> Result<(), ()>;
}
