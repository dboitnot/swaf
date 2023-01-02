#[macro_use]
extern crate rocket;

#[launch]
fn rocket() -> _ {
    swaf::launch()
}
