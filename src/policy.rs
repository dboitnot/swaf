use rocket::serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
pub struct User {
    pub login_name: String,
    pub full_name: Option<String>,
    pub is_admin: bool,
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

#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
pub struct PolicyStatement {
    pub effect: Effect,
    pub actions: Vec<String>,
    pub resources: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
pub enum Effect {
    Allow,
    Deny,
}
