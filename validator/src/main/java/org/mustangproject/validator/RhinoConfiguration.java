package org.mustangproject.validator;
import java.util.concurrent.atomic.AtomicBoolean;
import org.mozilla.javascript.ContextFactory;

public final class RhinoConfiguration {

    private static final AtomicBoolean INITIALIZED =
        new AtomicBoolean(false);

    private RhinoConfiguration() {}

    public static void initialize() {
        if (INITIALIZED.compareAndSet(false, true)) {
            try {
                ContextFactory.initGlobal(
                    new NativeImageContextFactory()
                );
            } catch (RuntimeException | Error e) {
                INITIALIZED.set(false);
                throw e;
            }
        }
    }

/** Runtime check that works in a native image (no -ea needed). */
    public static void verify() {
        ContextFactory global = ContextFactory.getGlobal();

        if (!(global instanceof NativeImageContextFactory)) {
            throw new IllegalStateException(
                "Wrong Rhino global ContextFactory: " + global.getClass().getName());
        }

        global.call(cx -> {
    int level = cx.getOptimizationLevel();
    if (level != -1) {
        throw new IllegalStateException(
            "Rhino optimization level is " + level + ", expected -1"
            + " | cx factory=" + cx.getFactory().getClass().getName()
            + " | global=" + ContextFactory.getGlobal().getClass().getName()
            + " | rhino=" + cx.getCurrentContext().getImplementationVersion());
    }


            // Functional smoke test: compiles and runs a script.
            // In compiled mode this would throw UnsupportedFeatureError.
            Object result = cx.evaluateString(
                cx.initStandardObjects(), "1 + 1", "smoke-test", 1, null);
            if (((Number) result).intValue() != 2) {
                throw new IllegalStateException("Rhino smoke test returned " + result);
            }else
{
//System.out.println("Rhino smoke test worked");
}
            return null;
        });
    }

}
