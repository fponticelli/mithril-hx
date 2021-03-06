package mithril.macros;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using Lambda;

class ModuleBuilder
{
	@macro public static function build() : Array<Field>
	{
		var c = Context.getLocalClass().get();
		if (c.meta.has(":processed")) return null;
		c.meta.add(":processed",[],c.pos);

		var fields = Context.getBuildFields();

		var propWarning = function(f : Field) {
			if (Lambda.exists(f.meta, function(m) return m.name == "prop")) {
				Context.warning("@prop only works with var", f.pos);
			}
		}

		for(field in fields) switch(field.kind) {
			case FFun(f):
				f.expr.iter(replaceM);
				if (field.name == "controller") injectModule(f);
				propWarning(field);
			case FVar(t, e):
				var prop = field.meta.find(function(m) return m.name == "prop");
				if (prop != null) {
					field.meta.remove(prop);
					field.access.push(Access.ADynamic);
					field.kind = propFunction(t, e);
				}
			case _:
				propWarning(field);
		}

		return fields;
	}

	/**
	 * Change: @prop public var description : String;
	 * To:     public dynamic function description(?v : String) : String return v;
	 */
	static private function propFunction(t : Null<ComplexType>, e : Expr) : FieldType {
		var f = {
			ret: t,
			params: null,
			expr: macro return v,
			args: [{
				value: null,
				type: t,
				opt: true,
				name: "v"
			}]
		}

		return FFun(f);
	}

	private static function replaceM(e : Expr) {
		switch(e) {
			case macro M($a, $b, $c):
				e.expr = (macro mithril.M.m($a, $b, $c)).expr;
				b.iter(replaceM);
				c.iter(replaceM);
			case macro M($a, $b):
				e.expr = (macro mithril.M.m($a, $b)).expr;
				b.iter(replaceM);
			case macro M($a):
				e.expr = (macro mithril.M.m($a)).expr;
			case _:
				e.iter(replaceM);
		}
	}

	private static function injectModule(f : Function) {
		if (f.expr == null) return;
		switch(f.expr.expr) {
			case EBlock(exprs):
				// If an anonymous object is used, don't call it.
				exprs.unshift(macro
					if (mithril.M.controllerModule != this &&
						Type.typeof(mithril.M.controllerModule) != Type.ValueType.TObject)
							return mithril.M.controllerModule.controller()
				);
				exprs.push(macro return this);
			case _:
				f.expr = {expr: EBlock([f.expr]), pos: f.expr.pos};
				injectModule(f);
		}
	}
}
#end