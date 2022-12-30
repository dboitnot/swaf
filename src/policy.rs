use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct User {
    pub login_name: String,
    pub full_name: Option<String>,
    pub is_admin: bool,
    pub groups: Vec<String>,
    pub policy_statements: Vec<PolicyStatement>,
}

#[derive(Deserialize, Debug)]
pub struct Group {
    pub name: String,
    pub description: Option<String>,
    pub policy_statements: Vec<PolicyStatement>,
}

#[derive(Deserialize, Debug)]
pub struct PolicyStatement {
    pub effect: Effect,
    pub actions: Vec<String>,
    pub resources: Vec<String>,
}

#[derive(Deserialize, Debug)]
pub enum Effect {
    Allow,
    Deny,
}
