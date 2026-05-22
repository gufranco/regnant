fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)
        .build_client(false)
        .compile_protos(
            &["proto/envoy/service/auth/v3/external_auth.proto"],
            &["proto"],
        )?;
    Ok(())
}
