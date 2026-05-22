//! regnant developer CLI.
//!
//! Wraps the Open Service Broker API plus a Keycloak device-code login
//! flow. Refresh tokens land in the OS keychain via the `keyring`
//! crate.

mod auth;
mod broker;
mod commands;
mod output;

use anyhow::Result;
use clap::{Parser, Subcommand};
use tracing_subscriber::EnvFilter;

#[derive(Debug, Parser)]
#[command(name = "regnant", version, about = "regnant developer CLI")]
struct Cli {
    #[arg(long, env = "REGNANT_API_URL", default_value = "http://localhost:8080")]
    api_url: String,

    #[arg(long, env = "REGNANT_USERNAME", default_value = "broker")]
    username: String,

    #[arg(long, env = "REGNANT_PASSWORD", hide_env_values = true, default_value = "changeme")]
    password: String,

    #[arg(long, value_enum, default_value_t = output::Format::Table)]
    output: output::Format,

    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Show the broker catalog.
    Catalog,
    /// Load balancer instance operations.
    #[command(subcommand)]
    Lb(LbCommand),
    /// Authentication helpers.
    #[command(subcommand)]
    Auth(AuthCommand),
}

#[derive(Debug, Subcommand)]
enum LbCommand {
    /// Provision a new load balancer.
    Create {
        #[arg(long, default_value = "regnant-lb-pro")]
        service: String,
        #[arg(long, default_value = "regnant-lb-pro-single")]
        plan: String,
        #[arg(long)]
        instance_id: Option<String>,
        #[arg(long)]
        product: Option<String>,
    },
    /// List all instances.
    List,
    /// Show one instance's status.
    Status {
        instance_id: String,
    },
    /// Deprovision an instance.
    Delete {
        instance_id: String,
        #[arg(long, default_value = "regnant-lb-pro")]
        service: String,
        #[arg(long, default_value = "regnant-lb-pro-single")]
        plan: String,
    },
    /// Bind an app to an instance.
    Bind {
        #[arg(long)]
        instance: String,
        #[arg(long)]
        app: String,
        #[arg(long, default_value = "regnant-lb-pro")]
        service: String,
        #[arg(long, default_value = "regnant-lb-pro-single")]
        plan: String,
    },
    /// Remove a binding.
    Unbind {
        #[arg(long)]
        instance: String,
        #[arg(long)]
        binding: String,
        #[arg(long, default_value = "regnant-lb-pro")]
        service: String,
        #[arg(long, default_value = "regnant-lb-pro-single")]
        plan: String,
    },
}

#[derive(Debug, Subcommand)]
enum AuthCommand {
    /// Run the Keycloak device-code flow and cache the refresh token.
    Login {
        #[arg(long, env = "KEYCLOAK_REALM_URL", default_value = "http://localhost:8090/realms/regnant")]
        realm: String,
        #[arg(long, default_value = "regnant-cli")]
        client_id: String,
    },
    /// Print the cached identity, if any.
    Whoami,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with_target(false)
        .compact()
        .init();

    let cli = Cli::parse();
    match cli.command {
        Command::Catalog => commands::catalog(&cli.api_url, &cli.username, &cli.password, cli.output).await,
        Command::Lb(cmd) => commands::lb(cmd, &cli.api_url, &cli.username, &cli.password, cli.output).await,
        Command::Auth(cmd) => commands::auth(cmd).await,
    }
}
