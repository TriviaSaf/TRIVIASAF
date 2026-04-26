import os
from flask import Blueprint, jsonify
from supabase import Client, create_client

admin_bp = Blueprint("admin_bp", __name__)


def _get_supabase_client() -> Client:
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    if not supabase_url or not supabase_key:
        raise RuntimeError("Variaveis SUPABASE_URL e SUPABASE_KEY nao configuradas.")
    return create_client(supabase_url, supabase_key)


@admin_bp.route("/logs", methods=["GET"])
def listar_logs():
    try:
        supabase = _get_supabase_client()
        result = (
            supabase.table("logs_auditoria")
            .select("*")
            .order("criado_em", desc=True)
            .limit(500)
            .execute()
        )
        return jsonify({"logs": result.data, "total": len(result.data)}), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@admin_bp.route("/usuarios", methods=["GET"])
def listar_usuarios():
    try:
        supabase = _get_supabase_client()
        result = (
            supabase.table("usuarios")
            .select("id, nome, email, perfil, ativo, criado_em")
            .order("nome")
            .execute()
        )
        return jsonify({"usuarios": result.data, "total": len(result.data)}), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500
