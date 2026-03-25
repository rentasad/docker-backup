#!/bin/bash

docker_is_excluded_stack() {
    local dir="$1"
    local container_name=""

    for excluded in "${EXCLUDED_STACK_DIRS[@]}"; do
        if [ "$dir" = "$excluded" ]; then
            log "Exclude ueber Working Dir: $dir"
            return 0
        fi
    done

    while read -r container_name; do
        [ -z "$container_name" ] && continue

        for excluded_container in "${EXCLUDED_CONTAINER_NAMES[@]}"; do
            if [ "$container_name" = "$excluded_container" ]; then
                log "Exclude ueber Containername: $container_name (Stack: $dir)"
                return 0
            fi
        done
    done < <(
        docker ps -a \
            --filter "label=com.docker.compose.project.working_dir=$dir" \
            --format '{{.Names}}'
    )

    return 1
}

docker_detect_active_stack_dirs() {
    docker ps --format '{{.ID}}' | while read -r cid; do
        docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$cid" 2>/dev/null
    done | sort -u | grep -v '^$' || true
}

docker_restart_stacks_from_file() {
    local stack_file="$1"

    if [ -z "${stack_file:-}" ] || [ ! -f "$stack_file" ]; then
        return 0
    fi

    log "--- Starte vorher aktive Docker Compose Stacks ---"

    while read -r dir; do
        [ -z "$dir" ] && continue

        if docker_is_excluded_stack "$dir"; then
            log "Ueberspringe ausgeschlossenen Stack in $dir"
            continue
        fi

        if [ -f "$dir/docker-compose.yml" ]; then
            echo "Starte Stack in $dir"
            docker compose -f "$dir/docker-compose.yml" up -d
        elif [ -f "$dir/compose.yml" ]; then
            echo "Starte Stack in $dir"
            docker compose -f "$dir/compose.yml" up -d
        fi
    done < "$stack_file"
}

docker_stop_stacks_from_file() {
    local stack_file="$1"

    log "--- Stoppe vorher aktive Docker Compose Stacks ---"

    while read -r dir; do
        [ -z "$dir" ] && continue

        if docker_is_excluded_stack "$dir"; then
            echo "Ueberspringe ausgeschlossenen Stack in $dir"
            continue
        fi

        if [ -f "$dir/docker-compose.yml" ]; then
            echo "Stoppe Stack in $dir"
            docker compose -f "$dir/docker-compose.yml" down || true
        elif [ -f "$dir/compose.yml" ]; then
            echo "Stoppe Stack in $dir"
            docker compose -f "$dir/compose.yml" down || true
        fi
    done < "$stack_file"
}
