# ambiente.sh — motor de container e imagem comuns aos scripts (usar com source).
#
# Podman ou Docker, o que houver (ENGINE=... força um deles). Docker com root
# gravaria bin/ e resultados/ como root: lá o container roda com o usuário do
# host. No Podman sem root, o root do container já é o próprio usuário.
ENGINE="${ENGINE:-$(command -v podman || command -v docker)}"
IMG="${IMG:-gem5-riscv:local}"
USUARIO=()
[[ "$ENGINE" == *docker ]] && USUARIO=(--user "$(id -u):$(id -g)" -e HOME=/tmp)

em_container() { "$ENGINE" run --rm "${USUARIO[@]}" "$@"; }
