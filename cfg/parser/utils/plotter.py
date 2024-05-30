from matplotlib.ticker import StrMethodFormatter

def plotter(data, experiment_name, scatter_labels=None, filename=None):
    try:
        import matplotlib
        matplotlib.use('Agg')
        from matplotlib import pyplot as plt
        import numpy as np
        import os
    except ModuleNotFoundError:
        return
    
    if filename is None:
        filename = experiment_name + ".png"
    
    # Plot data
    x_label, y_label = data.keys()
    x, y = data[x_label], data[y_label]
    
    plt.plot(x, y, alpha=.25)
    plt.scatter(x, y, alpha=.5)

    # Plot ideal
    x_min, x_max = min(x), max(x)

    def ideal_speed(cores):
        return y[0]/x[0] * cores

    ideal_range = np.arange(x_min, x_max, 1)
    ideal_speed = [ideal_speed(_x) for _x in ideal_range]
    plt.plot(ideal_range, ideal_speed, ":", alpha=.25, color="k")

    # Format stuff
    plt.xticks(x, [int(j) for j in x])
    plt.yticks(y, [int(j) for j in y])
    plt.title(os.path.splitext(os.path.basename(filename))[0])
    plt.xlabel(x_label)
    plt.ylabel(y_label)

    if not scatter_labels is None:
        for i, label in enumerate(scatter_labels):
            plt.annotate(label, (x[i] + 2, y[i]))

    plt.savefig(filename)
    plt.close()