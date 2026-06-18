#!/usr/bin/env bash
# build-repo.sh — Empacota todos os apps em .sdst e gera o index.json
# Uso: ./build-repo.sh
# Saída: packages/*.sdst + index.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
APPS_SOURCE="$SCRIPT_DIR/../packages"  # pasta packages/ na raiz do GoOS

mkdir -p "$PACKAGES_DIR"

echo "=== GoOS Constellation Repository Builder ==="
echo ""

# URL base onde este repositório será servido
# Altere conforme o seu servidor
REPO_BASE_URL="${REPO_BASE_URL:-http://localhost:8000}"

index_packages="[]"

build_package() {
    local app_dir="$1"
    local app_name
    app_name="$(basename "$app_dir")"

    local orbit_file="$app_dir/orbit.json"
    if [[ ! -f "$orbit_file" ]]; then
        echo "[skip] $app_name — sem orbit.json"
        return
    fi

    # Ler campos do orbit.json
    local version
    version=$(python3 -c "import json,sys; d=json.load(open('$orbit_file')); print(d.get('version','1.0.0'))")
    local description
    description=$(python3 -c "import json,sys; d=json.load(open('$orbit_file')); print(d.get('description',''))")
    local app_type
    app_type=$(python3 -c "import json,sys; d=json.load(open('$orbit_file')); print(d.get('app_type','NativeOffice'))")
    local app_icon
    app_icon=$(python3 -c "import json,sys; d=json.load(open('$orbit_file')); print(d.get('app_icon','📦'))")

    local sdst_name="${app_name}-${version}.sdst"
    local sdst_path="$PACKAGES_DIR/$sdst_name"
    local sdst_url="$REPO_BASE_URL/packages/$sdst_name"

    echo "📦 Empacotando $app_name v$version..."

    # Criar estrutura temporária
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap "rm -rf '$tmp_dir'" RETURN

    cp "$orbit_file" "$tmp_dir/orbit.json"

    # Copiar payload se existir
    if [[ -d "$app_dir/payload" ]]; then
        cp -r "$app_dir/payload" "$tmp_dir/payload"
    else
        mkdir -p "$tmp_dir/payload"
        # App sem payload local (usa container_image) → payload mínimo
        echo "#!/bin/bash" > "$tmp_dir/payload/start.sh"
        chmod +x "$tmp_dir/payload/start.sh"
    fi

    # Empacotar como tar.zst (.sdst)
    tar -C "$tmp_dir" -c --use-compress-program="zstd -T0 -19" -f "$sdst_path" .

    local size
    size=$(stat -c%s "$sdst_path")

    echo "   → $sdst_name ($(numfmt --to=iec $size))"

    # Adicionar ao índice JSON
    index_packages=$(python3 - <<EOF
import json, sys

pkgs = json.loads('''$index_packages''')
pkgs.append({
    "name":        "$app_name",
    "version":     "$version",
    "description": "$description",
    "app_type":    "$app_type",
    "app_icon":    "$app_icon",
    "url":         "$sdst_url",
    "size":        $size
})
print(json.dumps(pkgs, ensure_ascii=False))
EOF
)
}

# Empacotar cada app na pasta packages/
for app_dir in "$APPS_SOURCE"/*/; do
    [[ -d "$app_dir" ]] && build_package "$app_dir"
done

# Gerar index.json
python3 - <<EOF > "$SCRIPT_DIR/index.json"
import json
pkgs = json.loads('''$index_packages''')
index = {
    "version":  "1",
    "packages": pkgs
}
print(json.dumps(index, indent=2, ensure_ascii=False))
EOF

echo ""
echo "✅ index.json gerado com $(python3 -c "import json; d=json.load(open('$SCRIPT_DIR/index.json')); print(len(d['packages']))") pacote(s)."
echo ""
echo "Para servir localmente:"
echo "  cd $(realpath "$SCRIPT_DIR")"
echo "  python3 -m http.server 8000"
echo ""
echo "Para registrar no GoOS:"
echo "  constellation repo add $REPO_BASE_URL --name local"
