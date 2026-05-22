//! Output formatting: table, JSON, YAML.

use anyhow::Result;
use clap::ValueEnum;
use serde_json::Value;
use tabled::Table;

#[derive(Copy, Clone, Debug, ValueEnum)]
pub enum Format {
    Table,
    Json,
    Yaml,
}

pub fn print_value(value: &Value, format: Format) -> Result<()> {
    match format {
        Format::Json => {
            println!("{}", serde_json::to_string_pretty(value)?);
        }
        Format::Yaml => {
            println!("{}", serde_yaml::to_string(value)?);
        }
        Format::Table => print_table(value)?,
    }
    Ok(())
}

fn print_table(value: &Value) -> Result<()> {
    match value {
        Value::Array(rows) if rows.iter().all(Value::is_object) => print_object_array(rows)?,
        Value::Object(map) => {
            let rows: Vec<(String, String)> =
                map.iter().map(|(k, v)| (k.clone(), short(v))).collect();
            println!("{}", Table::new(rows));
        }
        other => println!("{other}"),
    }
    Ok(())
}

fn print_object_array(rows: &[Value]) -> Result<()> {
    if rows.is_empty() {
        println!("(empty)");
        return Ok(());
    }
    let mut keys: Vec<String> = Vec::new();
    if let Some(Value::Object(first)) = rows.first() {
        keys.extend(first.keys().cloned());
    }

    let mut table = Vec::with_capacity(rows.len());
    for row in rows {
        let mut cells: Vec<String> = Vec::with_capacity(keys.len());
        if let Value::Object(map) = row {
            for key in &keys {
                cells.push(short(map.get(key).unwrap_or(&Value::Null)));
            }
        }
        table.push(cells);
    }

    use tabled::builder::Builder;
    let mut builder = Builder::new();
    builder.push_record(keys);
    for row in table {
        builder.push_record(row);
    }
    println!("{}", builder.build());
    Ok(())
}

fn short(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        Value::Null => "-".into(),
        other => other.to_string(),
    }
}
