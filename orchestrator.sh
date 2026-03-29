#!/bin/bash

set -e

AGENT_DIR="$HOME/proyectos-propios/agents-workspace"

FRONT="$AGENT_DIR/blue-web"
BACK="$AGENT_DIR/blue-api"

STATE_DIR="$AGENT_DIR/state"
PROMPTS="$AGENT_DIR/prompts"
CONTEXT="$AGENT_DIR/context"

PLAN_FILE="$STATE_DIR/plan.json"
PROGRESS_FILE="$STATE_DIR/progress.json"

TARGET_BRANCH="develop"

mkdir -p "$STATE_DIR"

# ==========================================
# UTIL
# ==========================================

read_json() {
    expr="$1"
    python3 -c "import sys,json; data=json.load(sys.stdin); expr=sys.argv[1]; print(eval('data' + expr) if expr else data)" "$expr"
}

# ==========================================
# GENERAR PLAN
# ==========================================

generate_plan() {

    titulo=$1
    descripcion=$2

    echo ""
    echo "🧠 Generando plan con Claude..."

    business=$(cat "$CONTEXT/BUSINESS.md")
    architecture=$(cat "$CONTEXT/ARQUITECTURE.md")
    repo_tree=$(tree -L 3 "$FRONT" "$BACK")

    PROMPT=$(cat "$PROMPTS/planner.txt")

    PROMPT=${PROMPT//'{{titulo}}'/$titulo}
    PROMPT=${PROMPT//'{{descripcion}}'/$descripcion}
    PROMPT=${PROMPT//'{{business}}'/$business}
    PROMPT=${PROMPT//'{{architecture}}'/$architecture}
    PROMPT=${PROMPT//'{{repo_tree}}'/$repo_tree}

    claude --print --dangerously-skip-permissions "$PROMPT" > "$PLAN_FILE"

    echo "✓ Plan generado en $PLAN_FILE"

}

# ==========================================
# EJECUTAR TAREA
# ==========================================

execute_task() {

    task_title=$1

    echo ""
    echo "⚙️ Ejecutando tarea: $task_title"

    business=$(cat "$CONTEXT/BUSINESS.md")

    recent_diff_front=$(git -C "$FRONT" diff HEAD~3 2>/dev/null || true)
    recent_diff_back=$(git -C "$BACK" diff HEAD~3 2>/dev/null || true)

    PROMPT=$(cat "$PROMPTS/executor.txt")

    PROMPT=${PROMPT//'{{task}}'/$task_title}
    PROMPT=${PROMPT//'{{front}}'/$FRONT}
    PROMPT=${PROMPT//'{{back}}'/$BACK}
    PROMPT=${PROMPT//'{{business}}'/$business}
    PROMPT=${PROMPT//'{{recent_diff_front}}'/$recent_diff_front}
    PROMPT=${PROMPT//'{{recent_diff_back}}'/$recent_diff_back}

    claude --print --dangerously-skip-permissions "$PROMPT"

}

# ==========================================
# VALIDAR
# ==========================================

validate_code() {

    echo ""
    echo "🔎 Validando código..."

    cd "$FRONT"

    if ! npm run build; then
        return 1
    fi

    if ! npm run lint; then
        return 1
    fi

    cd "$BACK"

    if ! npm run build; then
        return 1
    fi

    if ! npm run test; then
        return 1
    fi

    echo "✓ Validación OK"

    return 0

}

# ==========================================
# FIX AGENT
# ==========================================

fix_build() {

    error_log=$1

    echo ""
    echo "🩹 Intentando autocorrección..."

    diff_front=$(git -C "$FRONT" diff)
    diff_back=$(git -C "$BACK" diff)

    PROMPT=$(cat "$PROMPTS/fix.txt")

    PROMPT=${PROMPT//'{{error}}'/$error_log}
    PROMPT=${PROMPT//'{{diff_front}}'/$diff_front}
    PROMPT=${PROMPT//'{{diff_back}}'/$diff_back}

    claude --print --dangerously-skip-permissions "$PROMPT"

}

# ==========================================
# COMMIT AUTOMÁTICO
# ==========================================

commit_changes() {

    msg=$1

    echo ""
    echo "💾 Commit automático..."

    cd "$FRONT"

    if ! git diff --quiet; then
        git add .
        git commit -m "$msg"
        git push origin $TARGET_BRANCH
    fi

    cd "$BACK"

    if ! git diff --quiet; then
        git add .
        git commit -m "$msg"
        git push origin $TARGET_BRANCH
    fi

}

# ==========================================
# GUARDAR PROGRESO
# ==========================================

save_progress() {

    task_index=$1

    echo "{\"task\": $task_index}" > "$PROGRESS_FILE"

}

# ==========================================
# CARGAR PROGRESO
# ==========================================

load_progress() {

if [ -f "$PROGRESS_FILE" ]; then
    cat "$PROGRESS_FILE" | read_json "['task']"
else
    echo 0
fi

}

# ==========================================
# ACTUALIZAR REPO_INDEX
# ==========================================

rebuild_repo_index() {

    echo ""
    echo "🗂 Reconstruyendo REPO_INDEX..."

    tree -L 4 "$FRONT/src" > "$CONTEXT/REPO_INDEX.md"
    echo "" >> "$CONTEXT/REPO_INDEX.md"
    tree -L 4 "$BACK/src" >> "$CONTEXT/REPO_INDEX.md"

    echo "✓ Repo index actualizado"

}

# ==========================================
# ACTUALIZAR CONTEXTO
# ==========================================

update_context() {

    titulo=$1
    descripcion=$2

    echo ""
    echo "🧠 Revisando contexto del sistema..."

    diff_front=$(git -C "$FRONT" diff HEAD~20 2>/dev/null || true)
    diff_back=$(git -C "$BACK" diff HEAD~20 2>/dev/null || true)

    business=$(cat "$CONTEXT/BUSINESS.md")
    architecture=$(cat "$CONTEXT/ARQUITECTURE.md")
    project=$(cat "$CONTEXT/PROJECT_CONTEXT.md")
    repo_index=$(cat "$CONTEXT/REPO_INDEX.md")

    PROMPT="Acabamos de terminar el siguiente proyecto:

        $titulo

        Descripción:
        $descripcion

        Cambios recientes frontend:

        $diff_front

        Cambios recientes backend:

        $diff_back

        Archivos de contexto actuales:

        ====================
        BUSINESS.md
        ====================
        $business

        ====================
        ARQUITECTURE.md
        ====================
        $architecture

        ====================
        PROJECT_CONTEXT.md
        ====================
        $project

        ====================
        REPO_INDEX.md
        ====================
        $repo_index


        Tarea:

        Revisar si estos archivos necesitan actualizarse según los cambios del proyecto.

        Reglas:

        - Actualizar SOLO si los cambios lo requieren
        - Mantener los archivos cortos
        - No agregar detalles irrelevantes
        - No duplicar información

        Si necesitas modificar archivos, edita directamente:

        $CONTEXT/BUSINESS.md
        $CONTEXT/ARQUITECTURE.md
        $CONTEXT/PROJECT_CONTEXT.md
        $CONTEXT/REPO_INDEX.md
    "

    cd "$AGENT_DIR"

    claude --dangerously-skip-permissions "$PROMPT"

    echo "✓ Contexto revisado"

}


# ==========================================
# EJECUTAR PLAN
# ==========================================

run_plan() {

    echo ""
    echo "🚀 Ejecutando plan..."

    total_tasks=$(cat "$PLAN_FILE" | read_json "['tasks'].__len__()")

    start_task=$(load_progress)

    echo "Total tareas: $total_tasks"
    echo "Reanudando desde: $start_task"

    for (( i=$start_task; i<$total_tasks; i++ ))
    do

        task_title=$(cat "$PLAN_FILE" | read_json "['tasks'][$i]['title']")

        echo ""
        echo "====================================="
        echo "TAREA $i / $total_tasks"
        echo "$task_title"
        echo "====================================="

        execute_task "$task_title"

        echo ""
        echo "🔧 Validando..."

        if validate_code; then

            commit_changes "feat: $task_title"

            save_progress $((i+1))

        else

            echo "❌ Falló la validación"

            error_log=$(validate_code 2>&1)

            fix_build "$error_log"

            echo "🔁 Reintentando validación..."

            if validate_code; then

                commit_changes "fix: $task_title"

                save_progress $((i+1))

            else

                echo ""
                echo "🚨 No se pudo arreglar automáticamente"
                exit 1

            fi

        fi

    done

    echo ""
    echo "🎉 PLAN COMPLETADO"

}

# ==========================================
# MAIN
# ==========================================

titulo=$1
descripcion=$2

if [ -z "$titulo" ]; then
    if [ ! -f "$AGENT_DIR/projects.json" ]; then
        echo "No se encontro projects.json y no se recibieron argumentos."
        echo "Uso:"
        echo "./orchestrator.sh \"titulo\" \"descripcion\""
        exit 1
    fi

    total_projects=$(cat "$AGENT_DIR/projects.json" | read_json ".__len__()")

    if [ "$total_projects" -eq 0 ]; then
        echo "projects.json no tiene tareas para ejecutar."
        exit 1
    fi

    titulo=$(cat "$AGENT_DIR/projects.json" | read_json "[0]['titulo']")
    descripcion=$(cat "$AGENT_DIR/projects.json" | read_json "[0]['descripcion']")
    project_branch=$(cat "$AGENT_DIR/projects.json" | read_json "[0].get('rama', '')")

    if [ -n "$project_branch" ]; then
        TARGET_BRANCH="$project_branch"
    fi

    echo "Proyecto cargado desde projects.json"
    echo "Titulo: $titulo"
    echo "Branch objetivo: $TARGET_BRANCH"
fi

generate_plan "$titulo" "$descripcion"

run_plan

rebuild_repo_index

update_context "$titulo" "$descripcion"

echo ""
echo "🏁 Proyecto finalizado"