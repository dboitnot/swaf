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
    fn group_named(&self, name: &str) -> Option<&Group>;
}

impl User {
    pub fn may_perform(
        &self,
        policy_store: Box<dyn PolicyStore>,
        action: &str,
        resource: &str,
    ) -> bool {
        matches!(
            self.groups
                .iter()
                .map(|g| policy_store.group_named(g))
                .filter(|o| o.is_some())
                .flat_map(|o| o.unwrap().policy_statements.iter())
                .chain(self.policy_statements.iter())
                .map(|s| s.effect_on(action, resource))
                .filter(|o| o.is_some())
                .flatten()
                .reduce(|acc, e| if acc == Effect::Deny { acc } else { e }),
            Some(Effect::Allow)
        )
    }
}
