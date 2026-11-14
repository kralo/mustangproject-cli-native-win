package org.mustangproject.validator;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.ContextFactory;
import org.mozilla.javascript.Callable;
import org.mozilla.javascript.Scriptable;

public class NativeImageContextFactory extends ContextFactory {
/*
    @Override
    protected Context makeContext() {
        Context cx = super.makeContext();

        cx.setOptimizationLevel(-1);
        System.err.println("Rhino interpreted mode active, level=" + cx.getOptimizationLevel());
        assert cx.getOptimizationLevel() == -1
            : "Rhino optimization is not disabled";

        return cx;
    }
*/

/*
@Override
protected Context makeContext() {
    Context cx = super.makeContext();
    int before = cx.getOptimizationLevel();
    cx.setOptimizationLevel(-1);


    System.err.println("makeContext: level " + before + " -> " + cx.getOptimizationLevel()
        + " on thread " + Thread.currentThread().getName());
    new Throwable("who created this context").printStackTrace();   // temporary

    return cx;
}
*/
  private static volatile boolean reported;
    @Override
    protected Context makeContext() {
        Context cx = super.makeContext();
        cx.setOptimizationLevel(-1);
        return cx;
    }

    @Override
    protected boolean hasFeature(Context cx, int feature) {
        if (cx.getOptimizationLevel() != -1 && !reported) {
            reported = true;
            new Throwable("level is " + cx.getOptimizationLevel() + " during compile")
                .printStackTrace();
        }
        return super.hasFeature(cx, feature);
    }

  
}
